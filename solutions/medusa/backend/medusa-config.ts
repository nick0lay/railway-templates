import { loadEnv, defineConfig, Modules } from "@medusajs/framework/utils"

loadEnv(process.env.NODE_ENV || "development", process.cwd())

const REDIS_URL = process.env.REDIS_URL
const BACKEND_URL = (process.env.MEDUSA_BACKEND_URL || "http://localhost:9000").replace(/\/+$/, "")

// Product images and other uploads go to the S3-compatible bucket when it is
// configured, and are served back through this server at /media/<key>
// (src/api/media). Without a bucket, files are kept on local disk.
const S3_ENABLED = Boolean(
  process.env.S3_BUCKET && process.env.S3_ACCESS_KEY_ID && process.env.S3_SECRET_ACCESS_KEY
)

const modules: any[] = [
  {
    key: Modules.FILE,
    resolve: "@medusajs/medusa/file",
    options: {
      providers: [
        S3_ENABLED
          ? {
              resolve: "@medusajs/medusa/file-s3",
              id: "s3",
              options: {
                file_url: `${BACKEND_URL}/media`,
                access_key_id: process.env.S3_ACCESS_KEY_ID,
                secret_access_key: process.env.S3_SECRET_ACCESS_KEY,
                region: process.env.S3_REGION || "auto",
                bucket: process.env.S3_BUCKET,
                endpoint: process.env.S3_ENDPOINT,
                // Railway buckets have no ACLs; files are served by /media.
                acl: false,
                additional_client_config: {
                  forcePathStyle: process.env.S3_FORCE_PATH_STYLE === "true",
                },
              },
            }
          : {
              resolve: "@medusajs/medusa/file-local",
              id: "local",
              options: { upload_dir: "static", backend_url: `${BACKEND_URL}/static` },
            },
      ],
    },
  },
]

if (REDIS_URL) {
  modules.push(
    {
      key: Modules.EVENT_BUS,
      resolve: "@medusajs/medusa/event-bus-redis",
      options: { redisUrl: REDIS_URL },
    },
    {
      key: Modules.WORKFLOW_ENGINE,
      resolve: "@medusajs/medusa/workflow-engine-redis",
      options: { redis: { redisUrl: REDIS_URL } },
    },
    {
      key: Modules.LOCKING,
      resolve: "@medusajs/medusa/locking",
      options: {
        providers: [
          {
            resolve: "@medusajs/medusa/locking-redis",
            id: "locking-redis",
            is_default: true,
            options: { redisUrl: REDIS_URL },
          },
        ],
      },
    }
  )
}

module.exports = defineConfig({
  projectConfig: {
    databaseUrl: process.env.DATABASE_URL,
    redisUrl: REDIS_URL,
    workerMode: (process.env.MEDUSA_WORKER_MODE as "shared" | "worker" | "server") || "shared",
    http: {
      storeCors: process.env.STORE_CORS!,
      adminCors: process.env.ADMIN_CORS!,
      authCors: process.env.AUTH_CORS!,
      jwtSecret: process.env.JWT_SECRET!,
      cookieSecret: process.env.COOKIE_SECRET!,
    },
  },
  admin: {
    disable: process.env.DISABLE_MEDUSA_ADMIN === "true",
  },
  modules,
})
