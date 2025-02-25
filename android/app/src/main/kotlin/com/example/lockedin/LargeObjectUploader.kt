package com.example.lockedin

import kotlinx.coroutines.*
import java.sql.Connection
import java.sql.DriverManager
import java.io.FileInputStream
import java.io.InputStream
import android.util.Log

object LargeObjectUploader {
    private const val DB_URL = "jdbc:postgresql://lockedinapp.cxw8gwiigwn7.eu-north-1.rds.amazonaws.com:5432/postgres"
    private const val USER = "postgres"
    private const val PASSWORD = "LockedIn123"

    fun upload(filePath: String, callback: (String?) -> Unit) {
        CoroutineScope(Dispatchers.IO).launch {
            var connection: Connection? = null
            try {
                Log.d("UPLOAD", "⚡ Establishing PostgreSQL connection...")

                // ✅ Use the correct PostgreSQL JDBC driver
                Class.forName("org.postgresql.Driver")

                // ✅ Establish Connection (runs off the UI thread)
                connection = withContext(Dispatchers.IO) {
                    DriverManager.getConnection(DB_URL, USER, PASSWORD)
                }

                // ✅ Prepare File Input
                val inputStream: InputStream = FileInputStream(filePath)
                val query = "INSERT INTO large_objects (data) VALUES (?) RETURNING oid"

                connection.prepareStatement(query).use { stmt ->
                    stmt.setBinaryStream(1, inputStream)

                    // ✅ Execute Query
                    stmt.executeQuery().use { rs ->
                        if (rs.next()) {
                            val oid = rs.getLong("oid").toString() // ✅ Get correct OID
                            Log.d("UPLOAD", "✅ Uploaded Successfully! OID: $oid")
                            withContext(Dispatchers.Main) {
                                callback(oid)
                            }
                        } else {
                            Log.e("UPLOAD", "❌ Upload failed, no OID returned.")
                            withContext(Dispatchers.Main) {
                                callback(null)
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e("UPLOAD_ERROR", "❌ Error uploading file", e)
                withContext(Dispatchers.Main) {
                    callback(null)
                }
            } finally {
                connection?.close()
                Log.d("UPLOAD", "🔄 Connection closed.")
            }
        }
    }
}
