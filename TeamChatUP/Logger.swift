//
//  Logger.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import Foundation
import OSLog

enum LogLevel: String {
    case debug = "�� DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
    case critical = "�� CRITICAL"
}

struct ErrorLog: Codable, Identifiable {
    let id: UUID
    let level: String
    let message: String
    let file: String
    let function: String
    let line: Int
    let timestamp: Date
    let errorDescription: String?
    
    init(level: LogLevel, message: String, file: String, function: String, line: Int, timestamp: Date, error: Error?) {
        self.id = UUID()
        self.level = level.rawValue
        self.message = message
        self.file = file
        self.function = function
        self.line = line
        self.timestamp = timestamp
        self.errorDescription = error?.localizedDescription
    }
}

struct NetworkLog: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let method: String
    let url: String
    let statusCode: Int?
    let requestHeaders: [String: String]?
    let requestBody: String?
    let responseBody: String?
    let error: String?
    let duration: TimeInterval?
}

final class AppLogger {
    static let shared = AppLogger()

    private let logger = Logger(subsystem: "com.teamchatup", category: "app")
    private var errorLogs: [ErrorLog] = []
    private var networkLogs: [NetworkLog] = []
    private let maxLogs = 100
    private let maxHTMLLogLength = 500
    private let queue = DispatchQueue(label: "com.teamchatup.logger", qos: .utility)

    private init() {}

    // MARK: - HTML Detection & Truncation

    private func isHTMLContent(_ content: String) -> Bool {
        let htmlIndicators = ["<!DOCTYPE html>", "<html", "<HTML", "<head>", "<body>", "<div", "<span"]
        return htmlIndicators.contains { content.contains($0) }
    }

    private func truncateHTML(_ content: String) -> String {
        guard content.count > maxHTMLLogLength else {
            return content
        }

        let preview = String(content.prefix(maxHTMLLogLength))
        let truncatedBytes = content.count - maxHTMLLogLength
        return "\(preview)...\n[HTML 內容已截斷，省略 \(truncatedBytes) 個字元]"
    }
    
    // MARK: - Logging Methods
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let fullMessage = error != nil ? "\(message) - \(error!.localizedDescription)" : message
        log(level: .error, message: fullMessage, file: file, function: function, line: line)
        
        let errorLog = ErrorLog(
            level: .error,
            message: fullMessage,
            file: (file as NSString).lastPathComponent,
            function: function,
            line: line,
            timestamp: Date(),
            error: error
        )
        addErrorLog(errorLog)
    }
    
    func critical(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let fullMessage = error != nil ? "\(message) - \(error!.localizedDescription)" : message
        log(level: .critical, message: fullMessage, file: file, function: function, line: line)
        
        let errorLog = ErrorLog(
            level: .critical,
            message: fullMessage,
            file: (file as NSString).lastPathComponent,
            function: function,
            line: line,
            timestamp: Date(),
            error: error
        )
        addErrorLog(errorLog)
    }
    
    private func log(level: LogLevel, message: String, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)"
        
        #if DEBUG
        print(logMessage)
        #endif
        
        switch level {
        case .debug:
            logger.debug("\(logMessage)")
        case .info:
            logger.info("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .error:
            logger.error("\(logMessage)")
        case .critical:
            logger.critical("\(logMessage)")
        }
    }
    
    private func addErrorLog(_ errorLog: ErrorLog) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.errorLogs.append(errorLog)
            if self.errorLogs.count > self.maxLogs {
                self.errorLogs.removeFirst()
            }
        }
    }
    
    // MARK: - Network Logging
    
    func logRequest(_ request: URLRequest, startTime: Date = Date()) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "UNKNOWN"
        
        var headers: [String: String] = [:]
        request.allHTTPHeaderFields?.forEach { headers[$0.key] = $0.value }
        
        var bodyString: String?
        if let body = request.httpBody {
            bodyString = String(data: body, encoding: .utf8)
        }
        
        let logMessage = """
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        �� REQUEST
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Method: \(method)
        URL: \(url)
        Headers: \(headers)
        Body: \(bodyString ?? "nil")
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """
        
        debug(logMessage)
    }
    
    func logResponse(_ response: HTTPURLResponse?, data: Data?, error: Error?, request: URLRequest, duration: TimeInterval) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "UNKNOWN"
        let statusCode = response?.statusCode ?? 0
        
        var responseString: String?
        var truncatedResponseString: String?
        if let data = data {
            responseString = String(data: data, encoding: .utf8)

            // 如果是 HTML 內容，截斷後顯示
            if let response = responseString, isHTMLContent(response) {
                truncatedResponseString = truncateHTML(response)
            } else {
                truncatedResponseString = responseString
            }
        }
        
        let logMessage = """
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        �� RESPONSE
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Method: \(method)
        URL: \(url)
        Status: \(statusCode)
        Duration: \(String(format: "%.2f", duration))s
        Error: \(error?.localizedDescription ?? "nil")
        Response: \(truncatedResponseString ?? "nil")
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """
        
        if error != nil || statusCode >= 400 {
            self.error(logMessage, error: error)
        } else {
            debug(logMessage)
        }
        
        // 記錄到網路日誌
        let networkLog = NetworkLog(
            id: UUID(),
            timestamp: Date(),
            method: method,
            url: url,
            statusCode: statusCode > 0 ? statusCode : nil,
            requestHeaders: request.allHTTPHeaderFields,
            requestBody: request.httpBody.flatMap { String(data: $0, encoding: .utf8) },
            responseBody: truncatedResponseString,
            error: error?.localizedDescription,
            duration: duration
        )
        
        queue.async { [weak self] in
            guard let self = self else { return }
            self.networkLogs.append(networkLog)
            if self.networkLogs.count > self.maxLogs {
                self.networkLogs.removeFirst()
            }
        }
    }
    
    // MARK: - Log Retrieval
    
    func getErrorLogs() -> [ErrorLog] {
        queue.sync {
            return errorLogs
        }
    }
    
    func getNetworkLogs() -> [NetworkLog] {
        queue.sync {
            return networkLogs
        }
    }
    
    func clearLogs() {
        queue.async { [weak self] in
            self?.errorLogs.removeAll()
            self?.networkLogs.removeAll()
        }
    }
    
    // MARK: - Export Logs
    
    func exportLogs() -> String {
        let errors = getErrorLogs()
        let networks = getNetworkLogs()
        
        var report = """
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        TeamChatUP 錯誤報告
        生成時間: \(Date())
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        """
        
        if !errors.isEmpty {
            report += "\n【錯誤日誌】(\(errors.count) 筆)\n\n"
            for (index, log) in errors.enumerated() {
                report += """
                \(index + 1). [\(log.level)] \(log.timestamp)
                   位置: \(log.file):\(log.line) - \(log.function)
                   訊息: \(log.message)
                   錯誤: \(log.errorDescription ?? "無")
                
                """
            }
        }
        
        if !networks.isEmpty {
            report += "\n【網路日誌】(\(networks.count) 筆)\n\n"
            for (index, log) in networks.enumerated() {
                report += """
                \(index + 1). [\(log.method)] \(log.timestamp)
                   URL: \(log.url)
                   狀態碼: \(log.statusCode?.description ?? "無")
                   耗時: \(log.duration.map { String(format: "%.2f", $0) } ?? "無")s
                   錯誤: \(log.error ?? "無")
                
                """
            }
        }
        
        return report
    }
    
    func saveLogsToFile() -> URL? {
        let report = exportLogs()
        let fileName = "teamchatup_logs_\(Date().timeIntervalSince1970).txt"
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try report.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            self.error("無法儲存日誌檔案", error: error)
            return nil
        }
    }
}
