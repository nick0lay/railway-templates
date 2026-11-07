// Added by the Railway template: a healthcheck that does not depend on the backend.
export const dynamic = "force-dynamic"

export function GET() {
  return Response.json({ status: "ok" })
}
