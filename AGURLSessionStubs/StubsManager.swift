/*
* JBoss, Home of Professional Open Source.
* Copyright Red Hat, Inc., and individual contributors
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import Foundation

typealias StubTestBlock = (NSURLRequest) -> Bool
typealias StubResponseBlock = (NSURLRequest) -> StubResponse

class StubsManager {
    
    var stubDescriptors = [StubDescriptor]();
    
    // holds the singleton StubManager
    class var sharedManager: StubsManager {

        struct Static {
            static let _instance = StubsManager()
        }
     
        return Static._instance
    }
    
    init() {
        Utils.swizzleFromSelector("defaultSessionConfiguration", toSelector: "swizzle_defaultSessionConfiguration", forClass: NSURLSessionConfiguration.classForCoder())
        
        Utils.swizzleFromSelector("ephemeralSessionConfiguration", toSelector: "swizzle_ephemeralSessionConfiguration", forClass: NSURLSessionConfiguration.classForCoder())
    }
    
    class func stubRequestsPassingTest(testBlock: StubTestBlock, withStubResponse responseBlock: StubResponseBlock) {
        let stubDesc = StubDescriptor(testBlock: testBlock, responseBlock: responseBlock)
        
        StubsManager.sharedManager.stubDescriptors += stubDesc
    }
    
    class func addStub(stubDescr: StubDescriptor) {
        StubsManager.sharedManager.stubDescriptors += stubDescr
    }
    
    class func removeStub(stubDescr: StubDescriptor) {
        if let index = find(StubsManager.sharedManager.stubDescriptors, stubDescr) {
            StubsManager.sharedManager.stubDescriptors.removeAtIndex(index)
        }
    }
    
    class func removeLastStub() {
        StubsManager.sharedManager.stubDescriptors.removeLast()
    }
    
    class func removeAllStubs() {
        StubsManager.sharedManager.stubDescriptors.removeAll(keepCapacity: false)
    }
    
    func firstStubPassingTestForRequest(request: NSURLRequest) -> StubDescriptor? {
        let count = stubDescriptors.count
        for (index, _) in enumerate(stubDescriptors) {
            let reverseIndex = count - (index + 1)
            let stubDescr = stubDescriptors[reverseIndex]
            
            if stubDescr.testBlock(request) {
                return stubDescr;
            }
        }
        
        return nil
    }
}

class StubDescriptor: Equatable {
    
    let testBlock: StubTestBlock
    let responseBlock: StubResponseBlock
    
    init(testBlock: StubTestBlock, responseBlock: StubResponseBlock) {
        self.testBlock = testBlock
        self.responseBlock = responseBlock
    }
}

@infix func ==(lhs: StubDescriptor, rhs: StubDescriptor) -> Bool {
    // identify check
    return lhs === rhs
}


class Utils {
    
    class func swizzleFromSelector(selector: CString!, toSelector: CString!, forClass:AnyClass!) {
        
        var originalMethod = class_getClassMethod(forClass, Selector.convertFromStringLiteral(selector))
        var swizzledMethod = class_getClassMethod(forClass, Selector.convertFromStringLiteral(toSelector))
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

extension NSURLSessionConfiguration {
    
    class func swizzle_defaultSessionConfiguration() -> NSURLSessionConfiguration! {
        let config = swizzle_defaultSessionConfiguration()
        
        var result = [AnyObject]()
        
        /*
        for proto in config.protocolClasses {
            result += proto
        }
        */
        // add our stub
        result += StubURLProtocol.classForCoder()
        config.protocolClasses = result
        
        return config
    }
    
    class func swizzle_ephemeralSessionConfiguration() -> NSURLSessionConfiguration! {
        let config = swizzle_ephemeralSessionConfiguration()
        
        var result = [AnyObject]()
        
        /*
        for proto in config.protocolClasses {
            result += proto
        }
        */
        // add our stub
        result += StubURLProtocol.classForCoder()
        config.protocolClasses = result
        
        return config
    }
}