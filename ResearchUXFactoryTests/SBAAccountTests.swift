//
//  SBAAccountTests.swift
//  ResearchUXFactory
//
//  Copyright (c) 2016 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import XCTest
@testable import ResearchUXFactory

class SBAAccountTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
        
    // MARK: Permissions
    
    func testPermssionsType_Some() {
        let permissionsStep = SBAPermissionsStep(identifier: "permissions",
                                                permissions: [.coremotion, .notifications, .microphone])
        
        let expectedItems = [SBAPermissionObjectType(permissionType: .coremotion),
                             SBANotificationPermissionObjectType(permissionType: .notifications),
                             SBAPermissionObjectType(permissionType: .microphone)]
        
        let actualItems = permissionsStep.items as? [SBAPermissionObjectType]
        
        XCTAssertNotNil(actualItems)
        guard actualItems != nil else { return }
        XCTAssertEqual(actualItems!, expectedItems)
    }
    
    func testPermssionsType_PhotoLibrary() {
        
        let inputItem: NSDictionary =      [
            "identifier"   : "permissions",
            "type"         : "permissions",
            "title"        : "Permissions",
            "text"         : "The following permissions are required for this activity. Please change these permissions via the iPhone Settings app before continuing.",
            "items"        : [[ "identifier"    : "photoLibrary",
                                "detail"        : "Allow the app to use the Photo Library"]],
            "optional"     : false,
            ]
        
        let permissionsStep = SBAPermissionsStep(inputItem: inputItem)
        XCTAssertNotNil(permissionsStep)
        
        let actualItems = permissionsStep?.items as? [SBAPermissionObjectType]
        
        XCTAssertNotNil(actualItems)
        XCTAssertEqual(actualItems?.count ?? 0, 1)
        
        guard let item = actualItems?.first else { return }
        XCTAssertEqual(item.permissionType, SBAPermissionTypeIdentifier.photoLibrary)
        XCTAssertEqual(item.detail, "Allow the app to use the Photo Library")

    }
    
    func testPermissionsType_InputItem() {
        
        let inputItem: NSDictionary =      [
            "identifier"   : "permissions",
            "type"         : "permissions",
            "title"        : "Permissions",
            "text"         : "The following permissions are required for this activity. Please change these permissions via the iPhone Settings app before continuing.",
            "items"        : ["coremotion", "microphone"],
            "optional"     : false,
        ]
        let step = SBAPermissionsStep(inputItem: inputItem)
        
        XCTAssertNotNil(step)
        guard let permissionsStep = step else { return }
        
        XCTAssertEqual(permissionsStep.identifier, "permissions")
        XCTAssertFalse(permissionsStep.isOptional)
        XCTAssertEqual(permissionsStep.title, "Permissions")
        XCTAssertEqual(permissionsStep.text, "The following permissions are required for this activity. Please change these permissions via the iPhone Settings app before continuing.")
        
        let expectedItems = [SBAPermissionObjectType(permissionType: .coremotion), SBAPermissionObjectType(permissionType: .microphone)]
        let actualItems = permissionsStep.items as? [SBAPermissionObjectType]
        
        XCTAssertNotNil(actualItems)
        guard actualItems != nil else { return }
        XCTAssertEqual(actualItems!, expectedItems)
    }
    
    // Mark: .registration
    
    func testCreateRegistrationStep() {
        let input: NSDictionary = [
            "identifier"    : "registration",
            "type"          : "registration",
            "title"         : "Registration"
        ]
        
        let result = SBABaseSurveyFactory().createSurveyStepWithDictionary(input)
        
        XCTAssertNotNil(result)
        guard let step = result as? ORKRegistrationStep else {
            XCTAssert(false, "\(result) not of expected type.")
            return
        }
        
        XCTAssertEqual(step.identifier, "registration")
        XCTAssertEqual(step.title, "Registration")
    }
    
    
    // Mark: SBAProfileInfoForm
    
    func testCreateProfileFormStep() {
        let input: NSDictionary = [
            "identifier"    : "profile",
            "type"          : "profile",
            "title"         : "Profile",
            "items"         : ["email", "password", "externalID", "name", "birthdate", "gender", "bloodType", "fitzpatrickSkinType", "wheelchairUse", "height", "weight", "wakeTime", "sleepTime", ["identifier" : "chocolate", "type" : "boolean","text" : "Do you like chocolate?"]]
        ]
        
        let step = SBAProfileFormStep(inputItem: input)
        XCTAssertEqual(step.identifier, "profile")
        XCTAssertEqual(step.title, "Profile")
        
        let emailItem = step.formItem(for:"email")
        let email = emailItem?.answerFormat as? ORKEmailAnswerFormat
        XCTAssertNotNil(emailItem)
        XCTAssertNotNil(email, "\(emailItem?.answerFormat)")
        
        let passwordItem = step.formItem(for:"password")
        let password = passwordItem?.answerFormat as? ORKTextAnswerFormat
        XCTAssertNotNil(passwordItem)
        XCTAssertNotNil(password, "\(passwordItem?.answerFormat)")

        let externalIDItem = step.formItem(for:"externalID")
        let externalID = externalIDItem?.answerFormat as? ORKTextAnswerFormat
        XCTAssertNotNil(externalIDItem)
        XCTAssertNotNil(externalID, "\(externalIDItem?.answerFormat)")
        
        let nameItem = step.formItem(for:"name")
        let name = nameItem?.answerFormat as? ORKTextAnswerFormat
        XCTAssertNotNil(nameItem)
        XCTAssertNotNil(name, "\(nameItem?.answerFormat)")
        
        let birthdateItem = step.formItem(for:"birthdate")
        let birthdate = birthdateItem?.answerFormat as? ORKHealthKitCharacteristicTypeAnswerFormat
        XCTAssertNotNil(birthdateItem)
        XCTAssertNotNil(birthdate, "\(birthdateItem?.answerFormat)")
        XCTAssertEqual(birthdate!.characteristicType.identifier, HKCharacteristicTypeIdentifier.dateOfBirth.rawValue)
        
        let genderItem = step.formItem(for:"gender")
        let gender = genderItem?.answerFormat as? ORKHealthKitCharacteristicTypeAnswerFormat
        XCTAssertNotNil(genderItem)
        XCTAssertNotNil(gender, "\(genderItem?.answerFormat)")
        XCTAssertEqual(gender!.characteristicType.identifier, HKCharacteristicTypeIdentifier.biologicalSex.rawValue)
        
        let bloodTypeItem = step.formItem(for:"bloodType")
        let bloodType = bloodTypeItem?.answerFormat as? ORKHealthKitCharacteristicTypeAnswerFormat
        XCTAssertNotNil(bloodTypeItem)
        XCTAssertNotNil(bloodType, "\(bloodTypeItem?.answerFormat)")
        XCTAssertEqual(bloodType!.characteristicType.identifier, HKCharacteristicTypeIdentifier.bloodType.rawValue)

        let fitzpatrickSkinTypeItem = step.formItem(for:"fitzpatrickSkinType")
        let fitzpatrickSkinType = fitzpatrickSkinTypeItem?.answerFormat as? ORKHealthKitCharacteristicTypeAnswerFormat
        XCTAssertNotNil(fitzpatrickSkinTypeItem)
        XCTAssertNotNil(fitzpatrickSkinType, "\(fitzpatrickSkinTypeItem?.answerFormat)")
        XCTAssertEqual(fitzpatrickSkinType!.characteristicType.identifier, HKCharacteristicTypeIdentifier.fitzpatrickSkinType.rawValue)

        let wheelchairUseItem = step.formItem(for:"wheelchairUse")
        XCTAssertNotNil(wheelchairUseItem)
        if #available(iOS 10.0, *) {
            let wheelchairUse = wheelchairUseItem?.answerFormat as? ORKHealthKitCharacteristicTypeAnswerFormat
            XCTAssertNotNil(wheelchairUse, "\(wheelchairUseItem?.answerFormat)")
            XCTAssertEqual(wheelchairUse!.characteristicType.identifier, HKCharacteristicTypeIdentifier.wheelchairUse.rawValue)
        }
        else {
            let wheelchairUse = wheelchairUseItem?.answerFormat as? ORKBooleanAnswerFormat
            XCTAssertNotNil(wheelchairUse, "\(wheelchairUseItem?.answerFormat)")
        }
        
        let heightItem = step.formItem(for:"height")
        let height = heightItem?.answerFormat as? ORKHealthKitQuantityTypeAnswerFormat
        XCTAssertNotNil(heightItem)
        XCTAssertNotNil(height, "\(heightItem?.answerFormat)")
        XCTAssertEqual(height!.quantityType.identifier, HKQuantityTypeIdentifier.height.rawValue)

        let weightItem = step.formItem(for:"weight")
        let weight = weightItem?.answerFormat as? ORKHealthKitQuantityTypeAnswerFormat
        XCTAssertNotNil(weightItem)
        XCTAssertNotNil(weight, "\(weightItem?.answerFormat)")
        XCTAssertEqual(weight!.quantityType.identifier, HKQuantityTypeIdentifier.bodyMass.rawValue)

        let wakeTimeItem = step.formItem(for:"wakeTime")
        let wakeTime = wakeTimeItem?.answerFormat as? ORKTimeOfDayAnswerFormat
        XCTAssertNotNil(wakeTimeItem)
        XCTAssertNotNil(wakeTime, "\(wakeTimeItem?.answerFormat)")
        let wakeHour = wakeTime?.defaultComponents?.hour
        XCTAssertNotNil(wakeHour)
        XCTAssertEqual(wakeHour!, 7)

        let sleepTimeItem = step.formItem(for:"sleepTime")
        let sleepTime = sleepTimeItem?.answerFormat as? ORKTimeOfDayAnswerFormat
        XCTAssertNotNil(sleepTimeItem)
        XCTAssertNotNil(sleepTime, "\(sleepTimeItem?.answerFormat)")
        let sleepHour = sleepTime?.defaultComponents?.hour
        XCTAssertNotNil(sleepHour)
        XCTAssertEqual(sleepHour!, 10)
        
        let chocolateItem = step.formItem(for:"chocolate")
        let chocolate = chocolateItem?.answerFormat as? ORKBooleanAnswerFormat
        XCTAssertNotNil(chocolateItem)
        XCTAssertNotNil(chocolate, "\(chocolateItem?.answerFormat)")
        XCTAssertEqual(chocolateItem?.text, "Do you like chocolate?")
    }

}
