//
//  ViewController.swift
//  BluetoothLeTest
//
//  Created by 小端 みより on 2016/07/14.
//  Copyright © 2016年 小端 みより. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate {

    let SERVICE_UUID = CBUUID(string: "5047b78a-33d8-49c4-abb5-6877abd6514d")
    let CHARACTERISTIC_UUID = CBUUID(string: "e3c9460b-33cf-4c1b-b097-5ba46633f585")

    @IBOutlet weak var mLabel: UILabel!
    @IBOutlet weak var mScanButton: UIButton!
    @IBOutlet weak var mTextField: UITextField!
    @IBOutlet weak var mAdvertiseButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // -- implementations for central
    
    var mCentralManager: CBCentralManager! = nil
    var mCentralInitializing = false;
    var mScanTimer: NSTimer! = nil
    var mPeripherals = Set<CBPeripheral>()

    @IBAction func scanButtonTouchDown(sender: AnyObject) {
        mLabel.text = "Initializing.."
        
        mCentralInitializing = true
        
        mCentralManager = CBCentralManager(delegate: self, queue: nil)
        
        mScanButton.enabled = false
    }
    
    @objc func scanTimeout(timer: NSTimer) {
        print("scan timeout")
        
        mCentralManager.stopScan();
        
        if mPeripherals.isEmpty {
            mLabel.text = "No peripheral found"
        }
        
        mScanTimer = nil
        
        cleanupCentral()
    }
    
    func cleanupCentral() {
        guard mCentralManager != nil else {
            return
        }
        
        if !mCentralInitializing && !mCentralManager.isScanning && mPeripherals.isEmpty {
            mCentralManager.delegate = nil
            mCentralManager = nil
            
            if mScanTimer != nil {
                mScanTimer.invalidate()
                mScanTimer = nil
            }
            
            mScanButton.enabled = true
        }
    }
    
    // -- CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        print("central state update: \(central.state.rawValue)")
        
        if mCentralInitializing {
            switch central.state {
            case CBCentralManagerState.Unsupported:
                mLabel.text = "Bluetooth is not supported"
                
                mCentralInitializing = false
                
                cleanupCentral()
                
            case CBCentralManagerState.PoweredOff:
                mLabel.text = "Please turn bluetooth on"
                
            case CBCentralManagerState.PoweredOn:
                mLabel.text = "Scanning..."
                
                mCentralInitializing = false
                
                mCentralManager.scanForPeripheralsWithServices([SERVICE_UUID], options: nil)
                
                mScanTimer = NSTimer.scheduledTimerWithTimeInterval(10.0,
                                                                    target: self,
                                                                    selector: #selector(ViewController.scanTimeout(_:)),
                                                                    userInfo: nil,
                                                                    repeats: false)
                
            default:
                break
            }
        }
    }
    
    func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
        print("will resore state: \(dict)")
    }
    
    func centralManager(central: CBCentralManager,
                        didDiscoverPeripheral peripheral: CBPeripheral,
                                              advertisementData: [String : AnyObject],
                                              RSSI: NSNumber) {
        print("discovered peripheral: \(peripheral)")
        
        mPeripherals.insert(peripheral)
        
        peripheral.delegate = self
        central.connectPeripheral(peripheral, options: nil)
        
        mLabel.text = "Connecting..."
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("connecting peripheral succeeded: \(peripheral)")
        
        peripheral.discoverServices([SERVICE_UUID])
        
        mLabel.text = "Disconvering services..."
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("connecting peripheral failed: \(peripheral), error: \(error)")
        
        mPeripherals.remove(peripheral)
        
        if mPeripherals.isEmpty {
            mLabel.text = "Connecting failed"
        }
        
        cleanupCentral()
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("peripheral disconnected: \(peripheral), error: \(error)")
        
        mPeripherals.remove(peripheral)
        
        cleanupCentral()
    }
    
    // -- CBPeripheralDelegate --
    
    func peripheralDidUpdateName(peripheral: CBPeripheral) {
        print("update name: \(peripheral.name)")
    }
    
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("modify services. invalidated: \(invalidatedServices)")
    }
    
    func peripheralDidUpdateRSSI(peripheral: CBPeripheral, error: NSError?) {
        print("update RSSI. error: \(error)")
    }
    
    func peripheral(peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
        print("read RSSI: \(RSSI), error: \(error)")
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        print("services discovered. error: \(error)")
        
        if (error == nil) && (peripheral.services != nil) {
            for service in peripheral.services! {
                print("service: \(service)")
                
                if service.UUID.isEqual(SERVICE_UUID) {
                    peripheral.discoverCharacteristics([CHARACTERISTIC_UUID], forService: service)
                    
                    mLabel.text = "Discovering characteristics..."
                    break
                }
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverIncludedServicesForService service: CBService, error: NSError?) {
        print("included service discovered. service: \(service), error: \(error)")
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        print("characteristics discovered. error: \(error)")
        
        if (error == nil) && (service.characteristics != nil) {
            for characteristic in service.characteristics! {
                print("characteristic: \(characteristic)")
                
                if characteristic.UUID.isEqual(CHARACTERISTIC_UUID) {
                    peripheral.readValueForCharacteristic(characteristic)
                    
                    mLabel.text = "Reading characteristic..."
                    break
                }
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("characteristic value updated. error: \(error)")
        
        if error == nil {
            print("characteristic: \(characteristic)")
            
            var str: String?
            
            if let value = characteristic.value {
                str = NSString(data:value, encoding: NSUTF8StringEncoding) as? String
            }
            
            mLabel.text = str ?? "No value"
            
            if mCentralManager.isScanning {
                mCentralManager.stopScan()
            }
            
            if mScanTimer != nil {
                mScanTimer.invalidate()
                mScanTimer = nil
            }
            
            mCentralManager.cancelPeripheralConnection(peripheral);
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("write characteristic value: \(characteristic), error: \(error)")
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("update characteristic notification state: \(characteristic), error: \(error)")
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("discover characteristic descripors: \(characteristic), error: \(error)")
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        print("update descriptor value: \(descriptor), error: \(error)")
    }
    
    func peripheral(peripheral: CBPeripheral, didWriteValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        print("write descriptor value: \(descriptor), error: \(error)")
    }
    
    
    // -- implementations for peripheral
    
    var mPeripheralManager: CBPeripheralManager! = nil
    var mPeripheralInitializing = false
    var mAdvertiseTimer: NSTimer! = nil
    
    @IBAction func advertiseButtonTouchDown(sender: AnyObject) {
        mLabel.text = "Initializing..."
        
        mPeripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: nil)
        
        mPeripheralInitializing = true
        
        mAdvertiseButton.enabled = false
    }
    
    func cleanupPeripheral() {
        guard mPeripheralManager != nil else {
            return
        }
        
        print("advertising: \(mPeripheralManager.isAdvertising)")
        
        if !mPeripheralInitializing && !mPeripheralManager.isAdvertising {
            mPeripheralManager.delegate = nil
            mPeripheralManager = nil
            
            if mAdvertiseTimer != nil {
                mAdvertiseTimer.invalidate()
                mAdvertiseTimer = nil
            }
            
            mAdvertiseButton.enabled = true;
        }
    }
    
    @objc func advertiseTimeout(timer: NSTimer) {
        print("advertise timeout")
        
        mPeripheralManager.stopAdvertising()
        
        mLabel.text = ""
        
        mAdvertiseTimer = nil
        
        NSTimer.scheduledTimerWithTimeInterval(0.1,
                                               target: self,
                                               selector: #selector(ViewController.cleanupPeripheralLater(_:)),
                                               userInfo: nil,
                                               repeats: false)
    }
    
    @objc func cleanupPeripheralLater(timer: NSTimer) {
        cleanupPeripheral();
    }
    
    // -- CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        print("peripheral state update: \(peripheral.state)")
        
        if mPeripheralInitializing {
            switch peripheral.state {
            case CBPeripheralManagerState.Unsupported:
                mLabel.text = "Bluetooth is not supported"
                
                mPeripheralInitializing = false
                
                cleanupPeripheral()
                
            case CBPeripheralManagerState.PoweredOff:
                mLabel.text = "Please turn bluetooth on"
                
            case CBPeripheralManagerState.PoweredOn:
                mLabel.text = "Advertising..."
                
                mPeripheralInitializing = false
                
                // register our service
                let characteristic = CBMutableCharacteristic(type: CHARACTERISTIC_UUID,
                                                             properties: CBCharacteristicProperties.Read,
                                                             value: nil,
                                                             permissions: CBAttributePermissions.Readable)
                let service = CBMutableService(type: SERVICE_UUID, primary: true)
                
                service.characteristics = [characteristic]
                
                peripheral.addService(service)
                
                // start advertising
                let advertisementData: [String: AnyObject] = [CBAdvertisementDataLocalNameKey: "TestDevice",
                                                              CBAdvertisementDataServiceUUIDsKey: [SERVICE_UUID]]
                peripheral.startAdvertising(advertisementData)
                
                mAdvertiseTimer = NSTimer.scheduledTimerWithTimeInterval(10.0,
                                                                         target: self,
                                                                         selector: #selector(ViewController.advertiseTimeout(_:)),
                                                                         userInfo: nil,
                                                                         repeats: false)
                
            default:
                break
            }
        }
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, willRestoreState dict: [String : AnyObject]) {
        print("will restore state: \(dict)")
    }
    
    func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
        print("start advertising. error: \(error)")
        
        if error != nil {
            peripheral.stopAdvertising()
            
            cleanupPeripheral()
        }
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, didAddService service: CBService, error: NSError?) {
        print("add service: \(service), error: \(error)")
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral,
                           didSubscribeToCharacteristic characteristic: CBCharacteristic) {
        print("subscribe characteristic. central: \(central), characteristic: \(characteristic)")
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral,
                           didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
        print("unsubscribe characteristic. central: \(central), characteristic: \(characteristic)")
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, didReceiveReadRequest request: CBATTRequest) {
        print("receive read request: \(request)")
        
        if request.characteristic.UUID.isEqual(CHARACTERISTIC_UUID) {
            if let text = mTextField.text {
                if let value = text.dataUsingEncoding(NSUTF8StringEncoding) {
                    request.value = value.subdataWithRange(NSRange(location: request.offset, length: value.length - request.offset));
                }
            }
            
            peripheral.respondToRequest(request, withResult: CBATTError.Success)
        }
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequests requests: [CBATTRequest]) {
        print("receive write request: \(requests)")
    }
    
    func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
        print("ready update subscribers");
    }

}

