import Foundation
import PapagaioCore

struct AnexoDeMidiaDaConversa: Identifiable, Equatable {
    let id: UUID
    let nome: String
    let tamanho: Int64
    let data: Date
    let url: URL

    var tipoVisual: String {
        let ext = url.pathExtension.localizedLowercase
        if ["png", "jpg", "jpeg", "heic", "gif", "tiff"].contains(ext) { return "Imagem" }
        if ["mov", "mp4", "m4v"].contains(ext) { return "Vídeo" }
        if ["pdf"].contains(ext) { return "PDF" }
        if ["mp3", "m4a", "wav", "aiff"].contains(ext) { return "Áudio" }
        return "Arquivo"
    }

    var simbolo: String {
        switch tipoVisual {
        case "Imagem": "photo"
        case "Vídeo": "film"
        case "PDF": "doc.richtext"
        case "Áudio": "waveform"
        default: "doc"
        }
    }

    var extensaoVisual: String {
        let ext = url.pathExtension.uppercased()
        return ext.isEmpty ? tipoVisual.uppercased() : ext
    }
}
