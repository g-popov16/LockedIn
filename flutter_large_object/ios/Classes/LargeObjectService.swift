import Foundation
import PostgresNIO
import NIOCore

struct LargeObjectService {
    private let eventLoopGroup: EventLoopGroup
    private let connectionPool: EventLoopGroupConnectionPool<PostgresConnectionSource>

    init(host: String, port: Int, username: String, password: String, database: String) {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let configuration = PostgresConnection.Configuration(
            host: host,
            port: port,
            username: username,
            password: password,
            database: database
        )
        let source = PostgresConnectionSource(configuration: configuration)
        self.connectionPool = EventLoopGroupConnectionPool(
            source: source,
            on: eventLoopGroup
        )
    }

    /// Saves a large object in PostgreSQL and returns its OID
    func saveLargeObject(inputStream: InputStream) async throws -> String {
        return try await connectionPool.withConnection { connection in
            return try await connection.simpleQuery("SELECT lo_creat(-1) AS oid").get().first.flatMap { row in
                row.column("oid")?.int
            }.map { oid in
                guard let oid = oid else {
                    throw NSError(domain: "PostgreSQL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create large object"])
                }

                return try await connection.simpleQuery("BEGIN").get()

                let handle = try await connection.simpleQuery("SELECT lo_open(\(oid), 131072) AS fd").get().first.flatMap { row in
                    row.column("fd")?.int
                }

                guard let fd = handle else {
                    throw NSError(domain: "PostgreSQL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to open large object"])
                }

                let bufferSize = 8192
                var buffer = [UInt8](repeating: 0, count: bufferSize)
                inputStream.open()
                while inputStream.hasBytesAvailable {
                    let readBytes = inputStream.read(&buffer, maxLength: bufferSize)
                    if readBytes > 0 {
                        let data = Data(buffer.prefix(readBytes))
                        let hexString = data.map { String(format: "%02x", $0) }.joined()
                        try await connection.simpleQuery("SELECT lowrite(\(fd), decode('\(hexString)', 'hex'))").get()
                    }
                }
                inputStream.close()

                try await connection.simpleQuery("SELECT lo_close(\(fd))").get()
                try await connection.simpleQuery("COMMIT").get()

                return String(oid)
            } ?? { throw NSError(domain: "PostgreSQL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to save large object"]) }()
        }
    }

    func shutdown() throws {
        try eventLoopGroup.syncShutdownGracefully()
    }
}
