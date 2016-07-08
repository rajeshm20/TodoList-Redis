/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation

import Kitura
import HeliumLogger
import LoggerAPI
import TodoListWeb
import CloudFoundryEnv
import TodoListAPI


Log.logger = HeliumLogger()



extension DatabaseConfiguration {
    
    init(withService: Service) {
        if let credentials = withService.credentials{
            self.host = credentials["public_hostname"].stringValue
            self.username = ""
            self.password = credentials["password"].stringValue
            self.port = UInt16(credentials["username"].stringValue)!
        } else {
            self.host = "http://aws-us-east-1-portal.18.dblayer.com/"
            self.username = ""
            self.password = "MLPGNOQGOPKSAITX"
            self.port = UInt16(10083)
        }
        self.options = [String : AnyObject]()
    }
}

let databaseConfiguration: DatabaseConfiguration
let todos: TodoList

do {
    print("TRYING TO RUN CLOUNDFOUNDRYENV!!!!!!!!!!!!!!!!!!!!!!!!!!!")
    Log.verbose("TRYING TO RUN CLOUNDFOUNDRYENV!!!!!!!!!!!!!!!!!!!!!!!!!!!")
    if let service = try CloudFoundryEnv.getAppEnv().getService(spec: "TodoList-Redis"){
        Log.verbose("Found TodoList-Redis on CloudFoundry")
        databaseConfiguration = DatabaseConfiguration(withService: service)
        Log.verbose("databaseConfiguration: \(databaseConfiguration.host), \(databaseConfiguration.port)")
        todos = TodoList(config: databaseConfiguration)
    } else {
        todos = TodoList()
    }
    
    let controller = TodoListController(backend: todos)
    let port = try CloudFoundryEnv.getAppEnv().port
    Log.verbose("Assigned port is \(port)")
    
    Kitura.addHTTPServer(onPort: port, with: controller.router)
    Kitura.run()
} catch CloudFoundryEnvError.InvalidValue {
    Log.error("Oops... something went wrong. Server did not start!")
}
//Server.run()
//Log.info("Server started on \(config.url).")