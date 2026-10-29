
import SwiftUI

struct ContentView: View {
    @State private var url = ""
    @State private var status = "Pegá una URL para comprobar el servidor."
    @State private var loading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("ZIP remoto") {
                    TextField("https://servidor/archivo.zip", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Comprobar URL") {
                        Task { await checkURL() }
                    }
                    .disabled(loading || url.isEmpty)
                }

                Section("Diagnóstico") {
                    Text(status)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("ZipFlow")
        }
    }

    @MainActor
    private func checkURL() async {
        guard let address = URL(string: url),
              ["http", "https"].contains(address.scheme?.lowercased() ?? "")
        else {
            status = "La URL no es válida."
            return
        }

        loading = true
        defer { loading = false }

        do {
            var request = URLRequest(url: address)
            request.httpMethod = "GET"
            request.setValue("bytes=0-3", forHTTPHeaderField: "Range")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                status = "El servidor no devolvió una respuesta HTTP."
                return
            }

            let prefix = String(
                decoding: data.prefix(100),
                as: UTF8.self
            )

            status = """
            HTTP: \(http.statusCode)
            URL final: \(http.url?.absoluteString ?? "desconocida")
            Tipo: \(http.value(forHTTPHeaderField: "Content-Type") ?? "desconocido")
            Tamaño: \(http.value(forHTTPHeaderField: "Content-Length") ?? "desconocido")
            Rangos: \(http.value(forHTTPHeaderField: "Accept-Ranges") ?? "no indicado")
            Primeros bytes: \(data.prefix(4).map {
                String(format: "%02X", $0)
            }.joined(separator: " "))
            Inicio de texto: \(prefix)
            """
        } catch {
            status = "Error de conexión: \(error.localizedDescription)"
        }
    }
}
