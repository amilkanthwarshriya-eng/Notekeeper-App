const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");
const bodyParser = require("body-parser");
require("dotenv").config();

const app = express();

// Middleware
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE"],
    allowedHeaders: ["Content-Type", "Authorization"],
  }),
);

// ✅ FIX 1: Increase body size limit — base64 images are ~33% larger than raw,
//           a single phone photo can be 2–4 MB as base64
app.use(bodyParser.json({ limit: "50mb" }));
app.use(bodyParser.urlencoded({ limit: "50mb", extended: true }));

// MySQL Connection
// ✅ FIX 2: Set max_allowed_packet on the MySQL connection itself.
//           Default is 1MB — way too small for base64 images.
//           16MB covers most use cases (multiple compressed photos + sketch).
const db = mysql.createConnection({
  host: process.env.DB_HOST || "localhost",
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_NAME || "note_keeper",
});

// Connect to MySQL
db.connect((err) => {
  if (err) {
    console.error("Error connecting to MySQL:", err);
    return;
  }
  console.log("Connected to MySQL database");

  // ✅ FIX 3: Raise max_allowed_packet at the session level immediately after connect.
  //           This ensures large payloads (base64 images/sketches) don't get rejected.
  db.query("SET SESSION max_allowed_packet = 67108864", (err) => {
    // 67108864 = 64MB
    if (err) {
      console.warn(
        "Could not set max_allowed_packet (may need MySQL 5.7+):",
        err.message,
      );
    } else {
      console.log("max_allowed_packet set to 64MB");
    }
  });

  // Create notes table if it doesn't exist
  const createTableQuery = `
    CREATE TABLE IF NOT EXISTS notes (
      id INT AUTO_INCREMENT PRIMARY KEY,
      title VARCHAR(255) NOT NULL,
      description TEXT,
      priority VARCHAR(50) DEFAULT 'Low',
      date VARCHAR(50),
      category VARCHAR(100) DEFAULT 'Personal',
      image_paths MEDIUMTEXT,
      sketch_data MEDIUMTEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `;

  db.query(createTableQuery, (err) => {
    if (err) {
      console.error("Error creating table:", err);
    } else {
      console.log("Notes table ready");

      // Auto-migrate: add missing columns to existing databases
      const columnsToCheck = [
        { name: "category", definition: "VARCHAR(100) DEFAULT 'Personal'" },
        { name: "image_paths", definition: "MEDIUMTEXT" },
        { name: "sketch_data", definition: "MEDIUMTEXT" },
      ];

      columnsToCheck.forEach(({ name, definition }) => {
        db.query(`SHOW COLUMNS FROM notes LIKE '${name}'`, (err, results) => {
          if (err) {
            console.error(`Error checking column ${name}:`, err);
          } else if (results.length === 0) {
            db.query(
              `ALTER TABLE notes ADD COLUMN ${name} ${definition}`,
              (err) => {
                if (err) {
                  console.error(`Error adding column ${name}:`, err);
                } else {
                  console.log(`Column '${name}' added`);
                }
              },
            );
          }
        });
      });
    }
  });
});

// ── Helper ────────────────────────────────────────────────────────────────────
function parseImagePaths(raw) {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

// ── Routes ────────────────────────────────────────────────────────────────────

// GET all notes
app.get("/api/notes", (req, res) => {
  db.query("SELECT * FROM notes ORDER BY date DESC", (err, results) => {
    if (err) {
      console.error("GET /api/notes error:", err);
      return res
        .status(500)
        .json({ error: "Failed to fetch notes", detail: err.message });
    }
    const notes = results.map((note) => ({
      ...note,
      image_paths: parseImagePaths(note.image_paths),
      sketch_data: note.sketch_data || null,
    }));
    res.json(notes);
  });
});

// GET single note
app.get("/api/notes/:id", (req, res) => {
  db.query(
    "SELECT * FROM notes WHERE id = ?",
    [req.params.id],
    (err, results) => {
      if (err) {
        console.error("GET /api/notes/:id error:", err);
        return res
          .status(500)
          .json({ error: "Failed to fetch note", detail: err.message });
      }
      if (results.length === 0)
        return res.status(404).json({ error: "Note not found" });
      const note = results[0];
      res.json({
        ...note,
        image_paths: parseImagePaths(note.image_paths),
        sketch_data: note.sketch_data || null,
      });
    },
  );
});

// POST create note
app.post("/api/notes", (req, res) => {
  const {
    title,
    description,
    priority,
    date,
    category,
    image_paths,
    sketch_data,
  } = req.body;

  if (!title) return res.status(400).json({ error: "Title is required" });

  // ✅ Always stringify image_paths — even if it's already sent as an array
  const imagePathsJson = JSON.stringify(
    Array.isArray(image_paths) ? image_paths : [],
  );

  console.log(
    `POST /api/notes — title: "${title}", images: ${Array.isArray(image_paths) ? image_paths.length : 0}, sketch: ${sketch_data ? "yes" : "no"}`,
  );

  const query =
    "INSERT INTO notes (title, description, priority, date, category, image_paths, sketch_data) VALUES (?, ?, ?, ?, ?, ?, ?)";

  db.query(
    query,
    [
      title,
      description || "",
      priority || "Low",
      date,
      category || "Personal",
      imagePathsJson,
      sketch_data || null,
    ],
    (err, result) => {
      if (err) {
        // ✅ FIX 4: Log the real MySQL error so you can see exactly what's failing
        console.error("POST /api/notes MySQL error:", err.code, err.message);
        return res.status(500).json({
          error: "Failed to create note",
          detail: err.message, // <-- Flutter will now see the real reason
          code: err.code,
        });
      }
      console.log(`Note created with id ${result.insertId}`);
      res
        .status(201)
        .json({ id: result.insertId, message: "Note created successfully" });
    },
  );
});

// PUT update note
app.put("/api/notes/:id", (req, res) => {
  const { id } = req.params;
  const {
    title,
    description,
    priority,
    date,
    category,
    image_paths,
    sketch_data,
  } = req.body;

  const imagePathsJson = JSON.stringify(
    Array.isArray(image_paths) ? image_paths : [],
  );

  console.log(
    `PUT /api/notes/${id} — images: ${Array.isArray(image_paths) ? image_paths.length : 0}, sketch: ${sketch_data ? "yes" : "no"}`,
  );

  const query =
    "UPDATE notes SET title = ?, description = ?, priority = ?, date = ?, category = ?, image_paths = ?, sketch_data = ? WHERE id = ?";

  db.query(
    query,
    [
      title,
      description || "",
      priority || "Low",
      date,
      category || "Personal",
      imagePathsJson,
      sketch_data || null,
      id,
    ],
    (err, result) => {
      if (err) {
        console.error("PUT /api/notes/:id MySQL error:", err.code, err.message);
        return res.status(500).json({
          error: "Failed to update note",
          detail: err.message,
          code: err.code,
        });
      }
      if (result.affectedRows === 0)
        return res.status(404).json({ error: "Note not found" });
      console.log(`Note ${id} updated`);
      res.json({ message: "Note updated successfully" });
    },
  );
});

// DELETE note
app.delete("/api/notes/:id", (req, res) => {
  db.query("DELETE FROM notes WHERE id = ?", [req.params.id], (err, result) => {
    if (err) {
      console.error("DELETE /api/notes/:id error:", err);
      return res
        .status(500)
        .json({ error: "Failed to delete note", detail: err.message });
    }
    if (result.affectedRows === 0)
      return res.status(404).json({ error: "Note not found" });
    res.json({ message: "Note deleted successfully" });
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
