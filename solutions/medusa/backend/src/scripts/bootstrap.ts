import type { ExecArgs } from "@medusajs/framework/types"
import { ContainerRegistrationKeys, Modules } from "@medusajs/framework/utils"
import {
  createApiKeysWorkflow,
  linkSalesChannelsToApiKeyWorkflow,
} from "@medusajs/medusa/core-flows"
import seedDemoData from "./seed"

// Runs before every server start (see start.sh). Safe to run again:
// 1. On an empty database, loads the demo store (regions, shipping, products)
//    unless SEED_DEMO_DATA=false.
// 2. Makes sure a publishable API key with the token in MEDUSA_PUBLISHABLE_KEY
//    exists and is linked to the default sales channel. The storefront is built
//    with the same value, so it works on the first deploy with no manual step.
export default async function bootstrap({ container, args }: ExecArgs) {
  const logger = container.resolve(ContainerRegistrationKeys.LOGGER)
  const regions = container.resolve(Modules.REGION)
  const apiKeys = container.resolve(Modules.API_KEY)
  const salesChannels = container.resolve(Modules.SALES_CHANNEL)
  const knex = container.resolve(ContainerRegistrationKeys.PG_CONNECTION)

  const [, regionCount] = await regions.listAndCountRegions({}, { take: 1 })
  if (regionCount === 0) {
    if (process.env.SEED_DEMO_DATA === "false") {
      logger.warn("bootstrap: no regions and SEED_DEMO_DATA=false; add a region in the admin before using the storefront")
    } else {
      logger.info("bootstrap: empty store, loading demo data")
      await seedDemoData({ container, args })
    }
  }

  const token = (process.env.MEDUSA_PUBLISHABLE_KEY || "").trim()
  if (!token) {
    logger.warn("bootstrap: MEDUSA_PUBLISHABLE_KEY is empty; the storefront needs a publishable key")
    return
  }
  const existing = await knex("api_key").where({ token, type: "publishable" }).whereNull("deleted_at").first()
  if (existing) {
    logger.info(`bootstrap: publishable key ${existing.id} already in place`)
    return
  }

  const [channel] = await salesChannels.listSalesChannels({ name: "Default Sales Channel" })
  let [key] = await apiKeys.listApiKeys({ type: "publishable", revoked_at: null } as any, { order: { created_at: "ASC" } as any })
  if (!key) {
    const { result } = await createApiKeysWorkflow(container).run({
      input: { api_keys: [{ title: "Storefront", type: "publishable", created_by: "" }] },
    })
    key = result[0] as any
    if (channel) {
      await linkSalesChannelsToApiKeyWorkflow(container).run({ input: { id: key.id, add: [channel.id] } })
    }
  }
  await knex("api_key").where({ id: key.id }).update({ token, redacted: token })
  logger.info(`bootstrap: publishable key ${key.id} now uses MEDUSA_PUBLISHABLE_KEY`)
}
