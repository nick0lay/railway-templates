import type { MedusaRequest, MedusaResponse } from "@medusajs/framework/http"
import { Modules } from "@medusajs/framework/utils"

// Serves uploaded media (product images) from the private bucket.
// Only image and video files are served, so private uploads such as
// product import CSVs never become public.
const TYPES: Record<string, string> = {
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  png: "image/png",
  gif: "image/gif",
  webp: "image/webp",
  avif: "image/avif",
  svg: "image/svg+xml",
  ico: "image/x-icon",
  mp4: "video/mp4",
  webm: "video/webm",
}

export async function GET(req: MedusaRequest, res: MedusaResponse) {
  const key = String(req.params.key || "")
  const ext = key.split(".").pop()?.toLowerCase() || ""
  if (!key || key.includes("..") || key.includes("/") || !TYPES[ext]) {
    res.status(404).send("Not found")
    return
  }
  const files = req.scope.resolve(Modules.FILE)
  let stream: NodeJS.ReadableStream
  try {
    stream = await files.getDownloadStream(key)
  } catch {
    res.status(404).send("Not found")
    return
  }
  res.setHeader("Content-Type", TYPES[ext])
  res.setHeader("Cache-Control", "public, max-age=31536000, immutable")
  res.setHeader("X-Content-Type-Options", "nosniff")
  res.setHeader("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; sandbox")
  stream.on("error", () => res.end())
  stream.pipe(res)
}
