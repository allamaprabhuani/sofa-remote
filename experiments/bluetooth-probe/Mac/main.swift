import AppKit
import CoreBluetooth
import Foundation

// Measurement only: no remote-input or access to Sofa Remote pairing data.
let serviceID = CBUUID(string: "A6E3A100-7FE8-4A6F-96CE-4FD880AE594B")
let requestID = CBUUID(string: "A6E3A101-7FE8-4A6F-96CE-4FD880AE594B")
let responseID = CBUUID(string: "A6E3A102-7FE8-4A6F-96CE-4FD880AE594B")

final class Probe: NSObject, CBPeripheralManagerDelegate {
    private var manager: CBPeripheralManager!
    private let response = CBMutableCharacteristic(type: responseID, properties: [.notify, .notifyEncryptionRequired], value: nil, permissions: [])
    override init() { super.init(); manager = CBPeripheralManager(delegate: self, queue: .main) }
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else { print("Bluetooth unavailable: \(peripheral.state.rawValue)"); return }
        let request = CBMutableCharacteristic(type: requestID, properties: [.write], value: nil, permissions: [.writeEncryptionRequired])
        let service = CBMutableService(type: serviceID, primary: true)
        service.characteristics = [request, response]
        peripheral.add(service)
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else { print("Service error: \(error!)"); return }
        peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceID], CBAdvertisementDataLocalNameKey: "Sofa Probe"])
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard request.characteristic.uuid == requestID, request.offset == 0,
                  let data = request.value, data.count == 4 else { peripheral.respond(to: request, withResult: .invalidAttributeValueLength); continue }
            peripheral.respond(to: request, withResult: .success)
            if !peripheral.updateValue(data, for: response, onSubscribedCentrals: [request.central]) {
                print("Response dropped: Bluetooth queue full")
            }
        }
    }
}
let app = NSApplication.shared
let probe = Probe()
withExtendedLifetime(probe) { app.run() }
