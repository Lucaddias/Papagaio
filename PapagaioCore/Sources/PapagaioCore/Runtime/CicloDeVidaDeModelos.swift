import Darwin
import Dispatch
import Foundation

/// Mantém os modelos residentes em memória entre execuções e os descarrega sob
/// pressão de memória.
///
/// Por que residente: carregar 10,7 GB do disco leva 10–30 s. Fazer isso a cada
/// resumo transformaria uma operação de segundos numa de meio minuto.
///
/// Por que descarregar: 10,7 GB num Mac de 18 GB é a maior parte da RAM. Sem
/// reagir à pressão, o app vira o candidato óbvio do jetsam — e é o processo do
/// usuário que morre, não o modelo.
public actor CicloDeVidaDeModelos {
    /// Um recurso caro que sabe se descarregar.
    public protocol Residente: AnyObject, Sendable {
        var identificador: String { get }
        func descarregar() async
    }

    private var residentes: [String: any Residente] = [:]
    private var monitor: DispatchSourceMemoryPressure?
    private var ultimoDescarte: Date?

    public init() {}

    /// Começa a observar pressão de memória. Idempotente.
    public func iniciarMonitoramento() {
        guard monitor == nil else { return }

        let fonte = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global(qos: .utility)
        )
        // O evento em si não é consultado: `.warning` e `.critical` levam ao
        // mesmo lugar. Não há meio termo útil com um modelo de 10,7 GB — ou ele
        // está na memória, ou não está.
        fonte.setEventHandler { [weak self] in
            Task { [weak self] in
                await self?.descarregarTudo()
            }
        }
        fonte.resume()
        monitor = fonte
    }

    public func pararMonitoramento() {
        monitor?.cancel()
        monitor = nil
    }

    public func registrar(_ residente: any Residente) {
        residentes[residente.identificador] = residente
    }

    public func remover(_ identificador: String) {
        residentes[identificador] = nil
    }

    public var identificadoresResidentes: [String] {
        Array(residentes.keys).sorted()
    }

    public var descartouRecentemente: Date? { ultimoDescarte }

    /// Descarrega tudo. Chamado sob pressão crítica e disponível para a UI.
    public func descarregarTudo() async {
        for (_, residente) in residentes {
            await residente.descarregar()
        }
        residentes.removeAll()
        ultimoDescarte = Date()
    }

    /// Memória física em uso pelo processo, para diagnóstico e testes.
    public static var memoriaDoProcesso: Int64 {
        var info = task_vm_info_data_t()
        var contagem = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let resultado = withUnsafeMutablePointer(to: &info) { ponteiro in
            ponteiro.withMemoryRebound(to: integer_t.self, capacity: Int(contagem)) { reapontado in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), reapontado, &contagem)
            }
        }
        guard resultado == KERN_SUCCESS else { return 0 }
        return Int64(info.phys_footprint)
    }
}
