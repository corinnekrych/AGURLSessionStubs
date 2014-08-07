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
public typealias ConfigFunction = () -> NSURLSessionConfiguration!
public typealias StubTestBlock = (NSURLRequest) -> Bool
public typealias StubResponseBlock = (NSURLRequest) -> StubResponse

public class StubsManager {
    
    private(set) var stubDescriptors = [StubDescriptor]()
    
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
    
    public class func stubRequestsPassingTest(testBlock: StubTestBlock, withStubResponse responseBlock: StubResponseBlock) -> StubDescriptor {
        let stubDesc = StubDescriptor(testBlock: testBlock, responseBlock: responseBlock)
        
        StubsManager.sharedManager.stubDescriptors += [stubDesc]
        
        return stubDesc
    }
    
    public class func addStub(stubDescr: StubDescriptor) {
        StubsManager.sharedManager.stubDescriptors += [stubDescr]
    }
    
    public class func removeStub(stubDescr: StubDescriptor) {
        if let index = find(StubsManager.sharedManager.stubDescriptors, stubDescr) {
            StubsManager.sharedManager.stubDescriptors.removeAtIndex(index)
        }
    }
    
    public class func removeLastStub() {
        StubsManager.sharedManager.stubDescriptors.removeLast()
    }
    
    public class func removeAllStubs() {
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

public class StubDescriptor: Equatable {
    
    let testBlock: StubTestBlock
    let responseBlock: StubResponseBlock
    
    init(testBlock: StubTestBlock, responseBlock: StubResponseBlock) {
        self.testBlock = testBlock
        self.responseBlock = responseBlock
    }
}

public func ==(lhs: StubDescriptor, rhs: StubDescriptor) -> Bool {
    // identify check
    return lhs === rhs
}


private class Utils {
    
    private class func swizzleFromSelector(selector: String!, toSelector: String!, forClass:AnyClass!) {
        
        var originalMethod = class_getClassMethod(forClass, Selector.convertFromStringLiteral(selector))
        var originalMethodImplementation:IMP = method_getImplementation(originalMethod);
        
        var swizzledMethod = class_getClassMethod(forClass, Selector.convertFromStringLiteral(toSelector))
        var swizzledMethodImplementation:IMP = method_getImplementation(swizzledMethod);
        
        method_setImplementation(originalMethod, swizzledMethodImplementation)
        method_setImplementation(swizzledMethod, originalMethodImplementation)
        //method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

extension NSURLSessionConfiguration {
    
    class func swizzle_defaultSessionConfiguration() -> NSURLSessionConfiguration! {
        println("inside swizzle")
        // as we've swap method, calling swizzled one here will call original one
        var config = swizzle_defaultSessionConfiguration()
        
        var result = [AnyObject]()
        
        for proto in config.protocolClasses {
            result += [proto]
        }

        // add our stub
        result.insert(StubURLProtocol.classForCoder(), atIndex: 0)
        config.protocolClasses = result
        
        return config
    }
    
    class func swizzle_ephemeralSessionConfiguration() -> NSURLSessionConfiguration! {
        let config = swizzle_ephemeralSessionConfiguration()
        
        var result = [AnyObject]()
        
        for proto in config.protocolClasses {
            result += [proto]
        }

        // add our stub
        result.insert(StubURLProtocol.classForCoder(), atIndex: 0)
        config.protocolClasses = result
        
        return config
    }
}