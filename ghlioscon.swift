#!/usr/bin/swift

/**
 * Ghlioscon - Guitar Hero Live iOS controller for macOS
 * Copyright (c) 2019 Kyungdahm Yun (tomyun@gmail.com)
 * https://github.com/tomyun/ghlioscon
 */

import CoreBluetooth
import Foundation
import IOKit

/**
 +--------+-------+-------+-------+-------+-------+-------+-------+-------+
 |        | Bit 7 | Bit 6 | Bit 5 | Bit 4 | Bit 3 | Bit 2 | Bit 1 | Bit 0 |
 +--------+-------+-------+-------+-------+-------+-------+-------+-------+
 | Byte 0 | SDown |  SUp  |   W3  |   W2  |   W1  |   B3  |   B2  |   B1  |
 +--------+-------+-------+-------+-------+-------+-------+-------+-------+
 | Byte 1 |       |       |       |       | Power |  Hero |  GHTV | Pause |
 +--------+-------+-------+-------+-------+-------+-------+-------+-------+
 | Byte 2 |                        Whammy (0 - 127)                       |
 +--------+---------------------------------------------------------------+
 | Byte 3 |                      Tilt (0 - 128 - 255)                     |
 +--------+---------------------------------------------------------------+
 */
let guitarReportDescriptor: [CUnsignedChar] = [
    0x05, 0x01,                    // USAGE_PAGE (Generic Desktop)
    0x09, 0x05,                    // USAGE (Game Pad)
    0xa1, 0x01,                    // COLLECTION (Application)
//  0x85, 0x01,                    //   REPORT_ID (1)
    0x05, 0x09,                    //   USAGE_PAGE (Button)
    0x19, 0x01,                    //   USAGE_MINIMUM (Button 1)
    0x29, 0x0c,                    //   USAGE_MAXIMUM (Button 12)
    0x15, 0x00,                    //   LOGICAL_MINIMUM (0)
    0x25, 0x01,                    //   LOGICAL_MAXIMUM (1)
    0x95, 0x0c,                    //   REPORT_COUNT (12)
    0x75, 0x01,                    //   REPORT_SIZE (1)
    0x81, 0x02,                    //   INPUT (Data,Var,Abs)
    0x95, 0x01,                    //   REPORT_COUNT (1)
    0x75, 0x04,                    //   REPORT_SIZE (4)
    0x81, 0x03,                    //   INPUT (Cnst,Var,Abs)
    0x05, 0x01,                    //   USAGE_PAGE (Generic Desktop)
    0x09, 0x30,                    //   USAGE (X)
    0x15, 0x00,                    //   LOGICAL_MINIMUM (0)
    0x25, 0x7f,                    //   LOGICAL_MAXIMUM (127)
    0x75, 0x08,                    //   REPORT_SIZE (8)
    0x95, 0x01,                    //   REPORT_COUNT (1)
    0x81, 0x02,                    //   INPUT (Data,Var,Abs)
    0x09, 0x31,                    //   USAGE (Y)
    0x15, 0x00,                    //   LOGICAL_MINIMUM (0)
    0x26, 0xff, 0x00,              //   LOGICAL_MAXIMUM (255)
    0x75, 0x08,                    //   REPORT_SIZE (8)
    0x95, 0x01,                    //   REPORT_COUNT (1)
    0x81, 0x02,                    //   INPUT (Data,Var,Abs)
    0xc0                           // END_COLLECTION
]

struct GuitarReport {
    var buttons: UInt16 = 0
    var whammy: UInt8 = 0
    var tilt: UInt8 = 0
}

class VirtualDriver {
    let SERVICE_NAME = "it_unbit_foohid"
    let FOOHID_CREATE:  UInt32 = 0
    let FOOHID_DESTROY: UInt32 = 1
    let FOOHID_SEND:    UInt32 = 2

    let DEVICE_NAME = "Guitar Hero Live iOS Controller"
    let DEVICE_SN = "20190616"
    let VENDOR_ID = 0x0000
    let PRODUCT_ID = 0x0000
    let LOCATION_ID = 0xFFFFFFFF

    var connect: io_connect_t = 0
    var runLoop: CFRunLoop!

    func open() {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(SERVICE_NAME), &iterator) == KERN_SUCCESS
        else {
            print("Unable to access IOService.")
            return
        }
        defer { IOObjectRelease(iterator) }

        guard let service: io_object_t = (sequence(state: iterator) {
            let service = IOIteratorNext($0)
            return service != IO_OBJECT_NULL ? service : nil
        }.first {
            if IOServiceOpen($0, mach_task_self_, 0, &connect) == KERN_SUCCESS {
                return true
            } else {
                IOObjectRelease($0)
                return false
            }
        }) else {
            print("Unable to open IOService.")
            return
        }
        defer { IOObjectRelease(service) }
        print("IOService is ready.")
    }

    func create() {
        guitarReportDescriptor.withUnsafeBufferPointer { desc in
            let input: [UInt64] = [
                unsafeBitCast(strdup(DEVICE_NAME), to: UInt64.self),
                UInt64(DEVICE_NAME.utf8.count),
                unsafeBitCast(desc.baseAddress, to: UInt64.self),
                UInt64(desc.count),
                unsafeBitCast(strdup(DEVICE_SN), to: UInt64.self),
                UInt64(DEVICE_SN.utf8.count),
                UInt64(VENDOR_ID),
                UInt64(PRODUCT_ID),
                UInt64(LOCATION_ID)
            ]
            guard IOConnectCallScalarMethod(connect, FOOHID_CREATE, input, UInt32(input.count), nil, nil) == KERN_SUCCESS
            else {
                print("Unable to create HID device. Maybe fine if already created.")
                return
            }
        }
        print("HID device is ready.")
    }

    func send(report: GuitarReport) {
        withUnsafePointer(to: report) { report in
            let input: [UInt64] = [
                unsafeBitCast(strdup(DEVICE_NAME), to: UInt64.self),
                UInt64(DEVICE_NAME.utf8.count),
                UInt64(UInt(bitPattern: report)),
                UInt64(MemoryLayout<GuitarReport>.stride)
            ]
            guard IOConnectCallScalarMethod(connect, FOOHID_SEND, input, UInt32(input.count), nil, nil) == KERN_SUCCESS
            else {
                print("Unable to send data to HID device.")
                return
            }
        }
        print(report)
    }

    func close() {
        let input: [UInt64] = [
            unsafeBitCast(strdup(DEVICE_NAME), to: UInt64.self),
            UInt64(DEVICE_NAME.utf8.count),
        ]
        guard IOConnectCallScalarMethod(connect, FOOHID_DESTROY, input, UInt32(input.count), nil, nil) == KERN_SUCCESS
        else {
            print("Unable to destroy HID device. Maybe fine if it wasn't created.")
            return
        }
        guard IOServiceClose(connect) == KERN_SUCCESS
        else {
            print("Unable to close IOService.")
            return
        }
        print("IOService closed.")
    }

    func run() {
        runLoop = CFRunLoopGetCurrent()
        CFRunLoopRun()
    }

    func stop() {
        CFRunLoopStop(runLoop)
    }
}

class BluetoothManager: NSObject {
    let advertisedUUID = CBUUID(string: "1523")
    let serviceUUID = CBUUID(string: "533E1523-3ABE-F33F-CD00-594E8B0A8EA3")
    let characteristicUUID = CBUUID(string: "533E1524-3ABE-F33F-CD00-594E8B0A8EA3")

    weak var driver: VirtualDriver?
    var report: GuitarReport = GuitarReport()
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?

    init(driver: VirtualDriver) {
        self.driver = driver
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func scan() {
        if driver != nil {
            print("Scanning Bluetooth peripherals...")
            centralManager.scanForPeripherals(withServices: [advertisedUUID])
        }
    }

    func close() {
        if let p = peripheral {
            print("Disconnecting Bluetooth peripheral connection...")
            centralManager.cancelPeripheralConnection(p)
        }
        driver = nil
    }

    func update(data d: Data) {
        func testBit(_ byte: UInt8, _ position: UInt) -> UInt16 {
            return UInt16((byte >> position) & 1)
        }
        func testByte(_ byte: UInt8, _ value: UInt8) -> UInt16 {
            return (byte == value) ? 1 : 0
        }
        report.buttons = 0
        report.buttons |= testBit(d[0], 1)     << 0  // Black 1
        report.buttons |= testBit(d[0], 2)     << 1  // Black 2
        report.buttons |= testBit(d[0], 3)     << 2  // Black 3
        report.buttons |= testBit(d[0], 0)     << 3  // White 1
        report.buttons |= testBit(d[0], 4)     << 4  // White 2
        report.buttons |= testBit(d[0], 5)     << 5  // White 3
        report.buttons |= testByte(d[4], 0x00) << 6  // Strum Up
        report.buttons |= testByte(d[4], 0xff) << 7  // Strum Down
        report.buttons |= testBit(d[1], 1)     << 8  // Pause
        report.buttons |= testBit(d[1], 2)     << 9  // GHTV Access
        report.buttons |= testBit(d[1], 3)     << 10 // Hero Power
        report.buttons |= testBit(d[1], 4)     << 11 // Power
        report.whammy = UInt8(d[6] - 0x80)
        report.tilt = UInt8(d[19])
        driver!.send(report: report)
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth central is powered on.")
            scan()
        default:
            print("Bluetooth central is not powered on.")
            driver!.stop()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print(peripheral)
        peripheral.delegate = self
        self.peripheral = peripheral
        central.stopScan()
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral: CBPeripheral, error: Error?) {
        print("Bluetooth disconnected")
        if let e = error { print(e) }
        scan()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect: CBPeripheral, error: Error?) {
        print("Bluetooth failed to connect")
        if let e = error { print(e) }
        scan()
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            print(service)
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            print(characteristic)
            //peripheral.readValue(for: characteristic)
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid != characteristicUUID {
            print("unknown characterstic UUID: \(characteristic.uuid)")
            return
        }
        if let data = characteristic.value {
            update(data: data)
        }
    }
}

let driver = VirtualDriver()
driver.open()
driver.create()
signal(SIGINT) { _ in driver.stop() }
let manager = BluetoothManager(driver: driver)
driver.run()
manager.close()
driver.close()
