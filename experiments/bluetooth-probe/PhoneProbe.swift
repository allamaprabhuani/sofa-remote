import SwiftUI
import CoreBluetooth

private let serviceID = CBUUID(string: "A6E3A100-7FE8-4A6F-96CE-4FD880AE594B")
private let requestID = CBUUID(string: "A6E3A101-7FE8-4A6F-96CE-4FD880AE594B")
private let responseID = CBUUID(string: "A6E3A102-7FE8-4A6F-96CE-4FD880AE594B")

@MainActor final class Probe: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var status = "Starting Bluetooth…"
    private var manager: CBCentralManager!
    private var peer: CBPeripheral?
    private var request: CBCharacteristic?
    private var ready = false
    private var sequence: UInt32 = 0
    private var started: ContinuousClock.Instant?
    private var timeout: Task<Void, Never>?
    override init() { super.init(); manager = CBCentralManager(delegate: self, queue: .main) }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { status = "Bluetooth unavailable"; return }
        status = "Looking for Sofa Probe…"; central.scanForPeripherals(withServices: [serviceID])
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        central.stopScan(); peer = peripheral; peripheral.delegate = self; status = "Connecting…"; central.connect(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) { peripheral.discoverServices([serviceID]) }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) { status = "Connection failed" }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) { ready = false; started = nil; timeout?.cancel(); request = nil; status = "Disconnected" }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == serviceID }) else { status = "Service unavailable"; return }
        peripheral.discoverCharacteristics([requestID, responseID], for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let chars = service.characteristics, let write = chars.first(where: { $0.uuid == requestID }), let notify = chars.first(where: { $0.uuid == responseID }) else { status = "Characteristics unavailable"; return }
        request = write; peripheral.setNotifyValue(true, for: notify)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        ready = error == nil && characteristic.isNotifying
        status = ready ? "Connected. Tap Measure." : "Pairing or subscription failed"
    }
    func measure() {
        guard ready, let peer, let request, started == nil else { return }
        sequence &+= 1
        var big = sequence.bigEndian
        let data = withUnsafeBytes(of: &big) { Data($0) }
        started = ContinuousClock.now
        status = "Measuring…"
        peer.writeValue(data, for: request, type: .withResponse)
        timeout = Task { try? await Task.sleep(for: .seconds(5)); if !Task.isCancelled && started != nil { started = nil; status = "Timed out. Tap Measure to retry." } }
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil { started = nil; timeout?.cancel(); status = "Write failed" }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == responseID, let data = characteristic.value, data.count == 4,
              data.reduce(UInt32(0), { ($0 << 8) | UInt32($1) }) == sequence, let start = started else { return }
        let duration = start.duration(to: .now).components
        let ms = Double(duration.seconds) * 1000 + Double(duration.attoseconds) / 1e15
        started = nil; timeout?.cancel(); status = String(format: "Round trip: %.1f ms", ms)
    }
}
@main struct SofaBluetoothProbe: App {
    @StateObject private var probe = Probe()
    var body: some Scene { WindowGroup { VStack(spacing: 24) { Text("Sofa Bluetooth Probe").font(.title2); Text(probe.status); Button("Measure") { probe.measure() }.buttonStyle(.borderedProminent) }.padding() } }
}
