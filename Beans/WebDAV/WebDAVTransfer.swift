import Foundation

// Size-limited streaming transfer, same-root redirects, and cancellation with exactly one continuation resume.
final class WebDAVTransfer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let root: URL
    private let limit: Int64
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?
    private var task: URLSessionDataTask?
    private var session: URLSession?
    private var output: FileHandle?
    private let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    private var received: Int64 = 0
    private var cancelled = false
    private var completed = false

    init(root: URL, limit: Int64) { self.root = root; self.limit = limit }

    func run(_ request: URLRequest) async throws -> URL {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if cancelled {
                    lock.unlock(); continuation.resume(throwing: CancellationError()); return
                }
                self.continuation = continuation
                do {
                    guard FileManager.default.createFile(atPath: destination.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
                    output = try FileHandle(forWritingTo: destination)
                    let configuration = URLSessionConfiguration.ephemeral
                    configuration.timeoutIntervalForRequest = 30
                    configuration.timeoutIntervalForResource = 600
                    configuration.httpShouldSetCookies = false
                    configuration.urlCache = nil
                    session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                    task = session?.dataTask(with: request)
                    task?.resume()
                    lock.unlock()
                } catch {
                    lock.unlock(); finish(.failure(error))
                }
            }
        }, onCancel: { self.cancel() })
    }

    private func cancel() {
        lock.lock(); cancelled = true; let active = task; lock.unlock()
        active?.cancel()
        finish(.failure(CancellationError()))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        do {
            guard let url = request.url else { throw WebDAVError.outsideRoot }
            _ = try WebDAVPaths.validate(url, root: root)
            var forwarded = request
            if let original = task.originalRequest {
                forwarded.setValue(original.value(forHTTPHeaderField: "Authorization"), forHTTPHeaderField: "Authorization")
                if original.httpMethod == "PUT" || original.httpMethod == "PROPFIND" {
                    forwarded.httpMethod = original.httpMethod
                    forwarded.httpBody = original.httpBody
                    for field in ["Depth", "Content-Type"] {
                        forwarded.setValue(original.value(forHTTPHeaderField: field), forHTTPHeaderField: field)
                    }
                }
            }
            completionHandler(forwarded)
        } catch { completionHandler(nil); finish(.failure(error)) }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        do {
            guard let http = response as? HTTPURLResponse, let finalURL = http.url else { throw URLError(.badServerResponse) }
            _ = try WebDAVPaths.validate(finalURL, root: root)
            guard (200..<300).contains(http.statusCode) else { throw WebDAVError.http(http.statusCode) }
            guard response.expectedContentLength <= limit else { throw WebDAVError.tooLarge }
            completionHandler(.allow)
        } catch { completionHandler(.cancel); finish(.failure(error)) }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard !completed else { lock.unlock(); return }
        received += Int64(data.count)
        do {
            guard received <= limit else { throw WebDAVError.tooLarge }
            try output?.write(contentsOf: data)
            lock.unlock()
        } catch { lock.unlock(); finish(.failure(error)); dataTask.cancel() }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(error)) }
        else { finish(.success(destination)) }
    }

    private func finish(_ result: Result<URL, Error>) {
        lock.lock()
        guard !completed, let continuation else { lock.unlock(); return }
        completed = true
        self.continuation = nil
        var finalResult = result
        do { try output?.close() } catch { finalResult = .failure(error) }
        output = nil
        let activeSession = session
        session = nil
        task = nil
        lock.unlock()
        if case .failure = finalResult {
            activeSession?.invalidateAndCancel()
            try? FileManager.default.removeItem(at: destination)
        } else { activeSession?.finishTasksAndInvalidate() }
        continuation.resume(with: finalResult)
    }
}
