import SwiftUI
import EstimoteUWB
import Alamofire

class UpdateData {
    // Properties
    var timestamp: Double
    var distance: Float
    var mac_tag: String // iPhone
    var mac_anchor: String // beacon
    
    // Initializzer
    init(timestamp: Double, distance: Float, mac_tag: String, mac_anchor: String) {
        self.timestamp = timestamp
        self.distance = distance
        self.mac_tag = mac_tag
        self.mac_anchor = mac_anchor
    }
    
    // Methods
    func getTimestamp() -> String {
        return timestamp.description
    }
    func getDistance() -> String {
        return distance.description
    }
    func getMac_tag() -> String {
        return mac_tag
    }
    func getMac_anchor() -> String {
        return mac_anchor
    }
}


struct MyVariables {
    static var sessionRunning = false
    static var mac_tag = UIDevice.current.identifierForVendor!.uuidString
    //static var mac_anchor = "unknow"
    static let server_ip = "192.168.1.34"
    static var updateList: [UpdateData] = []
    static var x = 0.0
    static var y = 0.0
}

struct ContentView: View {
    let uwb = UWBManagerExample()
    
    @State var buttonTitle: String = "Comenzar sesión"
    @State var descriptionTitle: String = "Pulse el botón para iniciar una nueva sesión"
    @State private var showOverlay = false
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    
    var body: some View {
        ZStack{
            Image("background")
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .edgesIgnoringSafeArea(.all)
            
            VStack {
                ZStack(alignment: .topLeading){
                    if #available(iOS 16.0, *) {
                        Image("map")
                            .resizable()
                            .frame(width: 400, height: 600)
                            .border(Color.blue)
                            .onTapGesture{
                                self.imageTapped(location: $0)
                            }
                        
                        if showOverlay {
                            Image("pointer")
                                .offset(x: MyVariables.x, y: MyVariables.y)
                                .transition(.opacity)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        withAnimation {
                                            self.showOverlay = false
                                        }
                                    }
                                }
                        }
                    }
                }
                
                
                Text(descriptionTitle)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button(action: {
                    changeSessionState()
                }, label:{
                    Text(buttonTitle)
                })
                .buttonStyle(.borderedProminent)
            }
            .onReceive(timer) { time in
                sendUpdate()
            }
            
        }
        
        
        
    }
    
    // Enviar la lista actual de datos de balizas al servidor
    func sendUpdate(){
        if(MyVariables.sessionRunning){
            var parameters: [[String:String]] = []
            for i in MyVariables.updateList {
                let item = ["timestamp": i.getTimestamp(),
                            "distance": i.getDistance(),
                            "mac_tag": i.getMac_tag(),
                            "mac_anchor": i.getMac_anchor()]
                
                parameters.append(item)
            }
            
            
            
            AF.request("http://\(MyVariables.server_ip):5103/update",
                       method: .post,
                       parameters: parameters,
                       encoder: JSONParameterEncoder.default).response { response in
                
                if let statusCode = response.response?.statusCode {
                        if (statusCode == 201) {
                            // Si se ha procesado correctamente la petición en el servidor, limpiamos
                            // la lista de muestras recopiladas hasta el momento
                            MyVariables.updateList.removeAll()
                        } else {
                            print("Error: \(statusCode)")
                        }
                    } else {
                        print("Error: \(response.error!)")
                    }
            }
        }
    }
    
    func imageTapped(location: CGPoint) {
        let timestamp = NSDate().timeIntervalSince1970
//        let xCoordinate = location.x
//        let yCoordinate = location.y
        MyVariables.x = location.x
        MyVariables.y = location.y
        self.showOverlay = true
        //print("Tap registered with coordinates (\(location.x),\(location.y))  at \(timestamp)")

        if (MyVariables.sessionRunning){
            let parameters = ["timestamp": timestamp.description,
                              "x": location.x.description,
                              "y": location.y.description]
            
            AF.request("http://\(MyVariables.server_ip):5103/user_pos_update",
                       method: .post,
                       parameters: parameters,
                       encoder: JSONParameterEncoder.default).response { response in
                //debugPrint(response)
            }
        }
            
        }
    
    
    
    func changeSessionState(){
        if(MyVariables.sessionRunning){
            // Enviar petición al servidor para terminar la sesión actual
            AF.request("http://\(MyVariables.server_ip):5103/close_session",
                       method: .get).response { response in
                if let statusCode = response.response?.statusCode {
                        if (statusCode == 200) {
                            // Si se ha procesado correctamente la petición en el servidor, cambiamos la GUI
                            buttonTitle = "Comenzar sesión"
                            descriptionTitle = "Sesión terminada. Pulse el botón para iniciar una nueva sesión."
                            
                            // Cambiamos la variable que nos informa del estado de la sesión
                            MyVariables.sessionRunning = false
                        } else {
                            print("Error: \(statusCode)")
                        }
                    } else {
                        print("Error: \(response.error!)")
                    }
            }
            
            
        }else{
            
            
            // Enviar petición al servidor para iniciar una nueva sesión
            AF.request("http://\(MyVariables.server_ip):5103/open_session",
                       method: .get).response { response in
                if let statusCode = response.response?.statusCode {
                        if (statusCode == 200) {
                            // Si se ha procesado correctamente la petición en el servidor, cambiamos la GUI
                            buttonTitle = "Terminar sesión"
                            descriptionTitle = "Sesión en ejecución..."
                            
                            // Cambiamos la variable que nos informa del estado de la sesión
                            MyVariables.sessionRunning = true
                        } else {
                            print("Error: \(statusCode)")
                        }
                    } else {
                        print("Error: \(response.error!)")
                    }
            }
            
            
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
        
    }
}

class UWBManagerExample {
    private var uwbManager: EstimoteUWBManager?
    
    init() {
        setupUWB()
    }
    
    private func setupUWB() {
        uwbManager = EstimoteUWBManager(positioningObserver: self,
                                        discoveryObserver: self,
                                        beaconRangingObserver: self)
        uwbManager?.startScanning()
        
    }
}

// OPTIONAL PROTOCOL FOR BEACON BLE RANGING
extension UWBManagerExample: BeaconRangingObserver {
    func didRange(for beacon: BLEDevice) {
        print("hello?")
        print("beacon did range: \(beacon)")
    }
}

// REQUIRED PROTOCOL
extension UWBManagerExample: UWBPositioningObserver {
    func didUpdatePosition(for device: UWBDevice) {
        if(MyVariables.sessionRunning){
            // Create new update object
            let newUpdate = UpdateData(timestamp: NSDate().timeIntervalSince1970,
                                       distance: device.distance,
                                       mac_tag: MyVariables.mac_tag,
                                       mac_anchor: device.publicId)
            // Save to updateList
            MyVariables.updateList.append(newUpdate)
        }
    }
}



// PROTOCOL FOR DISCOVERY AND CONNECTIVITY CONTROL
extension UWBManagerExample: UWBDiscoveryObserver {
    var shouldConnectAutomatically: Bool {
        return true
    }
    
    func didDiscover(device: UWBIdentifable, with rssi: NSNumber, from manager: EstimoteUWBManager) {
        print("Discovered Device: \(device.publicId)")
    }
    
    func didConnect(to device: UWBIdentifable) {
        print("Successfully Connected to: \(device.publicId)")
    }
    
    func didDisconnect(from device: UWBIdentifable, error: Error?) {
        print("Disconnected from device: \(device.publicId)- error: \(String(describing: error))")
    }
    
    func didFailToConnect(to device: UWBIdentifable, error: Error?) {
        print("Failed to conenct to: \(device.publicId) - error: \(String(describing: error))")
    }
}

