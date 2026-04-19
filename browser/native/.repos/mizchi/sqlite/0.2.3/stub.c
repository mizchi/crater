#include <sqlite3.h>
#include <moonbit.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

// Helper to convert MoonBit Bytes to C string
// @encoding.encode_utf8() returns UTF-8 encoded bytes, so we copy directly and add NULL terminator
static char* bytes_to_cstring(moonbit_bytes_t bytes) {
    int32_t len = Moonbit_array_length(bytes);
    char* str = (char*)malloc(len + 1);
    memcpy(str, bytes, len);
    str[len] = '\0';
    return str;
}

// Open database (returns db on success, NULL on failure)
sqlite3* sqlite_open(moonbit_bytes_t filename) {
    char* fname = bytes_to_cstring(filename);
    sqlite3* db;
    int rc = sqlite3_open(fname, &db);
    free(fname);
    if (rc != SQLITE_OK) {
        sqlite3_close(db);
        return NULL;
    }
    return db;
}

// Open database with extended options
sqlite3* sqlite_open_v2(moonbit_bytes_t filename, int32_t flags, moonbit_bytes_t vfs) {
    char* fname = bytes_to_cstring(filename);
    char* vfs_str = NULL;
    if (Moonbit_array_length(vfs) > 0) {
        vfs_str = bytes_to_cstring(vfs);
    }

    sqlite3* db;
    int rc = sqlite3_open_v2(fname, &db, flags, vfs_str);

    free(fname);
    if (vfs_str) free(vfs_str);

    if (rc != SQLITE_OK) {
        sqlite3_close(db);
        return NULL;
    }
    return db;
}

// Check if pointer is NULL
int32_t sqlite_is_null(void* ptr) {
    return ptr == NULL ? 1 : 0;
}

int32_t sqlite_stmt_is_null(sqlite3_stmt* ptr) {
    return ptr == NULL ? 1 : 0;
}

// Close database
void sqlite_close(sqlite3* db) {
    sqlite3_close(db);
}

// Execute SQL (no result). Returns 0 on success
int32_t sqlite_exec(sqlite3* db, moonbit_bytes_t sql) {
    char* sql_str = bytes_to_cstring(sql);
    char* err_msg = NULL;
    int rc = sqlite3_exec(db, sql_str, NULL, NULL, &err_msg);
    free(sql_str);
    if (err_msg) {
        sqlite3_free(err_msg);
    }
    return rc;
}

// Create prepared statement (returns NULL on failure)
sqlite3_stmt* sqlite_prepare(sqlite3* db, moonbit_bytes_t sql) {
    char* sql_str = bytes_to_cstring(sql);
    sqlite3_stmt* stmt = NULL;
    int rc = sqlite3_prepare_v2(db, sql_str, -1, &stmt, NULL);
    free(sql_str);
    if (rc != SQLITE_OK) {
        return NULL;
    }
    return stmt;
}

// Finalize statement
void sqlite_finalize(sqlite3_stmt* stmt) {
    sqlite3_finalize(stmt);
}

// Bind parameter (1-indexed)
int32_t sqlite_bind_int(sqlite3_stmt* stmt, int32_t idx, int32_t value) {
    return sqlite3_bind_int(stmt, idx, value);
}

int32_t sqlite_bind_double(sqlite3_stmt* stmt, int32_t idx, double value) {
    return sqlite3_bind_double(stmt, idx, value);
}

int32_t sqlite_bind_text(sqlite3_stmt* stmt, int32_t idx, moonbit_bytes_t text) {
    char* text_str = bytes_to_cstring(text);
    int rc = sqlite3_bind_text(stmt, idx, text_str, -1, SQLITE_TRANSIENT);
    free(text_str);
    return rc;
}

// Step to next row. 100=SQLITE_ROW (has data), 101=SQLITE_DONE (finished)
int32_t sqlite_step(sqlite3_stmt* stmt) {
    return sqlite3_step(stmt);
}

// Get column value (0-indexed)
int32_t sqlite_column_int(sqlite3_stmt* stmt, int32_t col) {
    return sqlite3_column_int(stmt, col);
}

double sqlite_column_double(sqlite3_stmt* stmt, int32_t col) {
    return sqlite3_column_double(stmt, col);
}

// Return SQLite text column as MoonBit Bytes
// moonbit_bytes_t is a length-prefixed byte array
moonbit_bytes_t sqlite_column_text(sqlite3_stmt* stmt, int32_t col) {
    const unsigned char* text = sqlite3_column_text(stmt, col);
    int len = sqlite3_column_bytes(stmt, col);
    if (text == NULL || len == 0) {
        return moonbit_make_bytes(0, 0);
    }
    moonbit_bytes_t result = moonbit_make_bytes(len, 0);
    memcpy(result, text, len);
    return result;
}

// Reset statement (make it reusable)
void sqlite_reset(sqlite3_stmt* stmt) {
    sqlite3_reset(stmt);
}

// Error handling
int32_t sqlite_errcode(sqlite3* db) {
    return sqlite3_errcode(db);
}

const char* sqlite_errmsg(sqlite3* db) {
    return sqlite3_errmsg(db);
}

// Additional bind functions
int32_t sqlite_bind_null(sqlite3_stmt* stmt, int32_t idx) {
    return sqlite3_bind_null(stmt, idx);
}

// Note: Using int64_t for idx to avoid ABI issues with mixed 32/64-bit parameters
// on some platforms (Linux x86-64). MoonBit may pass parameters differently
// when mixing Int and Int64 types.
int32_t sqlite_bind_int64(sqlite3_stmt* stmt, int64_t idx, int64_t value) {
    return sqlite3_bind_int64(stmt, (int)idx, value);
}

int32_t sqlite_bind_blob(sqlite3_stmt* stmt, int32_t idx, moonbit_bytes_t blob) {
    int32_t len = Moonbit_array_length(blob);
    return sqlite3_bind_blob(stmt, idx, blob, len, SQLITE_TRANSIENT);
}

// Additional column getter functions
int64_t sqlite_column_int64(sqlite3_stmt* stmt, int32_t col) {
    return sqlite3_column_int64(stmt, col);
}

// Return SQLite BLOB column as MoonBit Bytes
moonbit_bytes_t sqlite_column_blob(sqlite3_stmt* stmt, int32_t col) {
    const void* blob = sqlite3_column_blob(stmt, col);
    int len = sqlite3_column_bytes(stmt, col);
    if (blob == NULL || len == 0) {
        return moonbit_make_bytes(0, 0);
    }
    moonbit_bytes_t result = moonbit_make_bytes(len, 0);
    memcpy(result, blob, len);
    return result;
}

int32_t sqlite_column_bytes(sqlite3_stmt* stmt, int32_t col) {
    return sqlite3_column_bytes(stmt, col);
}

int32_t sqlite_column_type(sqlite3_stmt* stmt, int32_t col) {
    return sqlite3_column_type(stmt, col);
}

// Metadata functions
int32_t sqlite_column_count(sqlite3_stmt* stmt) {
    return sqlite3_column_count(stmt);
}

const char* sqlite_column_name(sqlite3_stmt* stmt, int32_t col) {
    return sqlite3_column_name(stmt, col);
}

int32_t sqlite_changes(sqlite3* db) {
    return sqlite3_changes(db);
}

int64_t sqlite_last_insert_rowid(sqlite3* db) {
    return sqlite3_last_insert_rowid(db);
}

// Clear statement bindings
int32_t sqlite_clear_bindings(sqlite3_stmt* stmt) {
    return sqlite3_clear_bindings(stmt);
}

// Concurrency control
int32_t sqlite_busy_timeout(sqlite3* db, int32_t ms) {
    return sqlite3_busy_timeout(db, ms);
}

// Transaction management
int32_t sqlite_get_autocommit(sqlite3* db) {
    return sqlite3_get_autocommit(db);
}

int32_t sqlite_total_changes(sqlite3* db) {
    return sqlite3_total_changes(db);
}

// Statement introspection
const char* sqlite_sql(sqlite3_stmt* stmt) {
    const char* sql = sqlite3_sql(stmt);
    return sql ? sql : "";
}

int32_t sqlite_bind_parameter_count(sqlite3_stmt* stmt) {
    return sqlite3_bind_parameter_count(stmt);
}

int32_t sqlite_stmt_readonly(sqlite3_stmt* stmt) {
    return sqlite3_stmt_readonly(stmt);
}

// Extended error handling
int32_t sqlite_extended_errcode(sqlite3* db) {
    return sqlite3_extended_errcode(db);
}

// Copy error string to global buffer (static storage)
// Note: sqlite3_errstr returns static string, so we copy it
static char errstr_buffer[256];

const char* sqlite_errstr(int32_t errcode) {
    const char* msg = sqlite3_errstr(errcode);
    if (msg) {
        strncpy(errstr_buffer, msg, sizeof(errstr_buffer) - 1);
        errstr_buffer[sizeof(errstr_buffer) - 1] = '\0';
        return errstr_buffer;
    }
    return "";
}

// Get parameter name (copy static string to buffer)
static char param_name_buffer[256];

const char* sqlite_bind_parameter_name(sqlite3_stmt* stmt, int32_t idx) {
    const char* name = sqlite3_bind_parameter_name(stmt, idx);
    if (name) {
        strncpy(param_name_buffer, name, sizeof(param_name_buffer) - 1);
        param_name_buffer[sizeof(param_name_buffer) - 1] = '\0';
        return param_name_buffer;
    }
    return "";
}

int32_t sqlite_bind_parameter_index(sqlite3_stmt* stmt, moonbit_bytes_t name) {
    char* name_str = bytes_to_cstring(name);
    int idx = sqlite3_bind_parameter_index(stmt, name_str);
    free(name_str);
    return idx;
}

// Get database filename (copy static string to buffer)
static char db_filename_buffer[512];

const char* sqlite_db_filename(sqlite3* db, moonbit_bytes_t dbname) {
    char* dbname_str = bytes_to_cstring(dbname);
    const char* filename = sqlite3_db_filename(db, dbname_str);
    free(dbname_str);

    if (filename) {
        strncpy(db_filename_buffer, filename, sizeof(db_filename_buffer) - 1);
        db_filename_buffer[sizeof(db_filename_buffer) - 1] = '\0';
        return db_filename_buffer;
    }
    return "";
}

int32_t sqlite_db_readonly(sqlite3* db, moonbit_bytes_t dbname) {
    char* dbname_str = bytes_to_cstring(dbname);
    int readonly = sqlite3_db_readonly(db, dbname_str);
    free(dbname_str);
    return readonly;
}

// Get expanded SQL (dynamically allocated string)
static char expanded_sql_buffer[1024];

const char* sqlite_expanded_sql(sqlite3_stmt* stmt) {
    char* sql = sqlite3_expanded_sql(stmt);
    if (sql) {
        strncpy(expanded_sql_buffer, sql, sizeof(expanded_sql_buffer) - 1);
        expanded_sql_buffer[sizeof(expanded_sql_buffer) - 1] = '\0';
        sqlite3_free(sql);  // Important: free dynamically allocated string
        return expanded_sql_buffer;
    }
    return "";
}

// Interrupt running query
void sqlite_interrupt(sqlite3* db) {
    sqlite3_interrupt(db);
}

// Set/get resource limits
int32_t sqlite_limit(sqlite3* db, int32_t id, int32_t newVal) {
    return sqlite3_limit(db, id, newVal);
}
