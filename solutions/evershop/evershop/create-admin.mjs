import pg from "pg";
import bcrypt from "bcryptjs";

const { Pool } = pg;

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || "5432", 10),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: process.env.DB_SSLMODE === "disable" ? false : { rejectUnauthorized: false },
});

const email = process.env.ADMIN_EMAIL;
const password = process.env.ADMIN_PASSWORD;
const fullName = process.env.ADMIN_NAME || "Admin";

async function createAdmin(retries = 5) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      // Check if admin_user table exists
      const tableCheck = await pool.query(
        `SELECT EXISTS (
          SELECT FROM information_schema.tables
          WHERE table_name = 'admin_user'
        )`
      );

      if (!tableCheck.rows[0].exists) {
        if (attempt < retries) {
          console.log(
            `[create-admin] admin_user table not yet created, retrying (${attempt}/${retries})...`
          );
          await new Promise((r) => setTimeout(r, 5000));
          continue;
        }
        console.error("[create-admin] admin_user table does not exist after all retries");
        process.exit(1);
      }

      // Hash password (same as EverShop: bcryptjs with salt rounds 10)
      const salt = bcrypt.genSaltSync(10);
      const hash = bcrypt.hashSync(password, salt);

      // Upsert: insert if email doesn't exist, update password if it does
      const result = await pool.query(
        `INSERT INTO admin_user (status, email, password, full_name)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (email) DO UPDATE SET password = $3, full_name = $4`,
        [true, email, hash, fullName]
      );

      if (result.rowCount > 0) {
        console.log(`[create-admin] Admin user upserted: ${email}`);
      }

      await pool.end();
      process.exit(0);
    } catch (err) {
      if (attempt < retries) {
        console.log(
          `[create-admin] Error (attempt ${attempt}/${retries}): ${err.message}, retrying...`
        );
        await new Promise((r) => setTimeout(r, 5000));
      } else {
        console.error(`[create-admin] Failed after ${retries} attempts:`, err.message);
        await pool.end();
        process.exit(1);
      }
    }
  }
}

createAdmin();
