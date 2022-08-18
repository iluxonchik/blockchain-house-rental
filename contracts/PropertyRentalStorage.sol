// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

library MappingDataTypes {
    enum PropertyStatus { AWAITING_PRICE, READY_FOR_RENT, LISTED_FOR_RENT, RENTED }
    
    struct AddressMappingValue {
        address value;
        bool isSet;
    }
    
    struct UintMappingValue {
        uint256 value;
        bool isSet;
    }

    struct Property {
        address propertyAddr;
        uint256 monthlyPriceInWei;
        PropertyStatus status;

    }

    struct PropertyApplicant {
        address applicant;
        uint256 applicationTime;
        bool isSet;
    }
}

/*
    Storage map of all of the properties listed for rental, and their mapping to their owners.
    RentalAgreement uses this as a storage facility for the purpose of:
        * tracking which properties are listed for rental
        * keep a record of the owners of the property

    This contracts abstracts all of the housekeeping required to achieve the goals above.
*/
contract PropertyRentalStorage {
    modifier notInStorage(address propertyAddr) {
        require(propertyAddressToPropertiesForRentIndex[propertyAddr].isSet == false, "Property currently in the list of properties listed for rent. Please remove it first.");
        _;
    }

    modifier isInStorage(address propertyAddr) {
        require(propertyAddressToPropertiesForRentIndex[propertyAddr].isSet == true, "Property currently NOT in the list of properties listed for rent. Please add it there first.");
        _;
    }

    modifier notYetApplied(address propertyAddr, address applicantAddr) {
        require(propertyAddressToPropertyAppplicantsIndex[propertyAddr][applicantAddr].isSet == false, "Applicant already applied to rent this property");
        _;
    }

    modifier isListedForRent(address propertyAddr) {
        require(propertiesForRent[propertyAddressToPropertiesForRentIndex[propertyAddr].value].status == MappingDataTypes.PropertyStatus.LISTED_FOR_RENT, "Property is not listed for rent");
        _;
    }

    // map of property address to its owner
    mapping(address => MappingDataTypes.AddressMappingValue) public propertyAddressToOriginalOwner;
    // all properties listed for rental 
    MappingDataTypes.Property[] public propertiesForRent;
    // allow to acccess propertiesForRent in O(1)
    mapping(address => MappingDataTypes.UintMappingValue) public propertyAddressToPropertiesForRentIndex;
    
    // property address to list of applicants mapping
    mapping(address => MappingDataTypes.PropertyApplicant[]) public propertyApplicants;
    // allow access to property applicants in O(1). order: property address, aplicant address
    mapping(address => mapping(address => MappingDataTypes.UintMappingValue)) public propertyAddressToPropertyAppplicantsIndex;


    function _addPropertyToRentalMapping(address propertyAddr, address propertyOwnerAddr) internal notInStorage(propertyAddr) {
        propertyAddressToOriginalOwner[propertyAddr] = MappingDataTypes.AddressMappingValue(propertyOwnerAddr, true);
        propertiesForRent.push(MappingDataTypes.Property(propertyAddr, 0, MappingDataTypes.PropertyStatus.AWAITING_PRICE));
        uint256 elemIndex = propertiesForRent.length - 1;
        propertyAddressToPropertiesForRentIndex[propertyAddr] = MappingDataTypes.UintMappingValue(elemIndex, true);
    }

    function _removePropertyToRentalMapping(address propertyAddr) internal isInStorage(propertyAddr){
        uint256 indexToRemove = propertyAddressToPropertiesForRentIndex[propertyAddr].value;
        require(indexToRemove < propertiesForRent.length, "FATAL ERROR: attempting to remove index beyond the size of the array.");
        
        // begin remove properties from list of properties listed for rent
        MappingDataTypes.Property memory lastProperty = propertiesForRent[propertiesForRent.length - 1];
        propertiesForRent[indexToRemove] = lastProperty;
        
        // update index of moved property
        propertyAddressToPropertiesForRentIndex[lastProperty.propertyAddr].value = indexToRemove;

        // remove property from assistive mapping
        propertyAddressToPropertiesForRentIndex[propertyAddr].isSet = false;

        // remove property --> owner mapping
        propertyAddressToOriginalOwner[propertyAddr].value = address(0); // remove any history
        propertyAddressToOriginalOwner[propertyAddr].isSet = false;

        // end remove properties from list of properties listed for rent
        propertiesForRent.pop();
    }

    function isPropertyAdded(address propertyAddr) public view returns(bool) {
        return propertyAddressToPropertiesForRentIndex[propertyAddr].isSet;
    }

    function addProperty(address propertyAddr, address propertyOwnerAddr) public {
        _addPropertyToRentalMapping(propertyAddr, propertyOwnerAddr);
    }

    function removeProperty(address propertyAddr) public {
        _removePropertyToRentalMapping(propertyAddr);
    }

    function getProperty(address propertyAddr) public view isInStorage(propertyAddr) returns (MappingDataTypes.Property memory) {
        uint256 index = propertyAddressToPropertiesForRentIndex[propertyAddr].value;
        return propertiesForRent[index];
    }

    function getPropertyOriginalOwner(address propertyAddr) public view isInStorage(propertyAddr) returns (address){
        MappingDataTypes.AddressMappingValue memory property = propertyAddressToOriginalOwner[propertyAddr];
        return property.value;
    }

    // applicant applies to rent a property
    function applyForRent(address propertyAddr, address applicantAddr) isInStorage(propertyAddr) isListedForRent(propertyAddr) notYetApplied(propertyAddr, applicantAddr) public {
        propertyApplicants[propertyAddr].push(MappingDataTypes.PropertyApplicant(applicantAddr, block.timestamp, true));
        uint256 elemIndex = propertyApplicants[propertyAddr].length - 1;
        propertyAddressToPropertyAppplicantsIndex[propertyAddr][applicantAddr] = MappingDataTypes.UintMappingValue(elemIndex, true);
    }
}