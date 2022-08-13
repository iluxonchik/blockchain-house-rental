// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

library MappingDataTypes {
    struct AddressMappingValue {
        address value;
        bool isSet;
    }
    
    struct UintMappingValue {
        uint256 value;
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

    // map of property address to its owner
    mapping(address => MappingDataTypes.AddressMappingValue) public propertyAddressToOriginalOwner;
    // all properties listed for rental 
    address[] public propertiesForRent;
    // allow to acccess propertiesForRent in O(1)
    mapping(address => MappingDataTypes.UintMappingValue) public propertyAddressToPropertiesForRentIndex;


    function _addPropertyToRentalMapping(address propertyAddr, address propertyOwnerAddr) internal notInStorage(propertyAddr) {
        propertyAddressToOriginalOwner[propertyAddr] = MappingDataTypes.AddressMappingValue(propertyOwnerAddr, true);
        propertiesForRent.push(propertyAddr);
        uint256 elemIndex = propertiesForRent.length - 1;
        propertyAddressToPropertiesForRentIndex[propertyAddr] = MappingDataTypes.UintMappingValue(elemIndex, true);
    }

    function _removePropertyToRentalMapping(address propertyAddr) internal isInStorage(propertyAddr){
        uint256 indexToRemove = propertyAddressToPropertiesForRentIndex[propertyAddr].value;
        require(indexToRemove < propertiesForRent.length, "FATAL ERROR: attempting to remove index beyond the size of the array.");
        
        // begin remove properties from list of properties listed for rent
        address lastProperty = propertiesForRent[propertiesForRent.length - 1];
        propertiesForRent[indexToRemove] = lastProperty;
        
        // update index of moved property
        propertyAddressToPropertiesForRentIndex[lastProperty].value = indexToRemove;

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
}