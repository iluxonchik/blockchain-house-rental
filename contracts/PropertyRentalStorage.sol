// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

library MappingDataTypes {
    enum PropertyStatus { AWAITING_PRICE, READY_FOR_RENT, LISTED_FOR_RENT, AWAITING_PAYMENT, RENTED }
    
    struct AddressMappingValue {
        address value;
        bool isSet;
    }
    
    struct UintMappingValue {
        uint256 value;
        bool isSet;
    }

    struct PropertyApplicant {
        address applicant;
        uint256 applicationTime;
        bool isSet;
    }

    struct Property {
        address propertyAddr;
        uint256 monthlyPriceInWei;
        PropertyStatus status;
        PropertyApplicant selectedApplicant;
        uint256 applicantSelectTime;
        uint256 rentStartTime;
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
    mapping(MappingDataTypes.PropertyStatus => string) public propertyStatusToString;

    modifier notInStorage(address propertyAddr) {
        require(propertyAddressToPropertiesForRentIndex[propertyAddr].isSet == false, "Property currently in the list of properties listed for rent. Please remove it first.");
        _;
    }

    modifier isInStorage(address propertyAddr) {
        require(propertyAddressToPropertiesForRentIndex[propertyAddr].isSet == true, "Property currently NOT in the list of properties listed for rent. Please add it there first.");
        _;
    }

    modifier hasApplicantApplied(address propertyAddr, address applicantAddr) {
        require(hasApplied(propertyAddr, applicantAddr), "Address has not applied to rent this property");
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

    modifier isAwaitingPayment(address propertyAddr) {
        require(propertiesForRent[propertyAddressToPropertiesForRentIndex[propertyAddr].value].status == MappingDataTypes.PropertyStatus.AWAITING_PAYMENT, "Property is not in awaiting payment state");
        _;
    }

    modifier isReadyForRent(address propertyAddr) {
       require(propertiesForRent[propertyAddressToPropertiesForRentIndex[propertyAddr].value].status == MappingDataTypes.PropertyStatus.READY_FOR_RENT, "Property is not in ready for rent state");
        _;
    }

    constructor() {
        propertyStatusToString[MappingDataTypes.PropertyStatus.AWAITING_PRICE] = "Awaiting Price";
        propertyStatusToString[MappingDataTypes.PropertyStatus.READY_FOR_RENT] = "Ready For Rent";
        propertyStatusToString[MappingDataTypes.PropertyStatus.LISTED_FOR_RENT] = "Listed For Rent";
        propertyStatusToString[MappingDataTypes.PropertyStatus.RENTED] = "Rented";
    }

    // map of property address to its owner
    mapping(address => MappingDataTypes.AddressMappingValue) public propertyAddressToOriginalOwner;
    // all properties listed for rental 
    MappingDataTypes.Property[] public propertiesForRent;
    // allow to acccess propertiesForRent in O(1)
    mapping(address => MappingDataTypes.UintMappingValue) public propertyAddressToPropertiesForRentIndex;
    

    // (property, applicant) address pair to PropertyApplicant mapping
    mapping(address => mapping(address => MappingDataTypes.PropertyApplicant)) applicantAddrToPropertyApplicant;
    // property address to list of applicants mapping
    mapping(address => MappingDataTypes.PropertyApplicant[]) public propertyApplicants;
    // allow access to property applicants in O(1). order: property address, aplicant address
    mapping(address => mapping(address => MappingDataTypes.UintMappingValue)) public propertyAddressToPropertyAppplicantsIndex;


    function _addPropertyToRentalMapping(address propertyAddr, address propertyOwnerAddr) internal notInStorage(propertyAddr) {
        propertyAddressToOriginalOwner[propertyAddr] = MappingDataTypes.AddressMappingValue(propertyOwnerAddr, true);
        propertiesForRent.push(MappingDataTypes.Property(propertyAddr, 0, MappingDataTypes.PropertyStatus.AWAITING_PRICE, MappingDataTypes.PropertyApplicant(address(0), 0, false), 0, 0));
        uint256 elemIndex = propertiesForRent.length - 1;
        propertyAddressToPropertiesForRentIndex[propertyAddr] = MappingDataTypes.UintMappingValue(elemIndex, true);
    }

    function _removePropertyToRentalMapping(address propertyAddr) internal isInStorage(propertyAddr){
        uint256 indexToRemove = propertyAddressToPropertiesForRentIndex[propertyAddr].value;
        require(indexToRemove < propertiesForRent.length, "FATAL ERROR: attempting to remove index beyond the size of the array.");
        
        // begin remove properties from list of properties listed for rent
        MappingDataTypes.Property storage lastProperty = propertiesForRent[propertiesForRent.length - 1];
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

    function isPropertyListedForRent(address propertyAddr) public view returns (bool) {
        if (isPropertyAdded(propertyAddr)) {
            return _getProperty(propertyAddr).status == MappingDataTypes.PropertyStatus.LISTED_FOR_RENT;
        }
        return false;
    }

    function hasApplied(address propertyAddr, address applicantAddr) public view returns (bool){
        return propertyAddressToPropertyAppplicantsIndex[propertyAddr][applicantAddr].isSet;
    }

    function isSelectedApplicant(address propertyAddr, address applicantAddr) isInStorage(propertyAddr) hasApplicantApplied(propertyAddr, applicantAddr) isAwaitingPayment(propertyAddr) public view returns (bool) {
        MappingDataTypes.Property storage property = _getProperty(propertyAddr);
        return property.selectedApplicant.applicant == applicantAddr;
    }

    function addProperty(address propertyAddr, address propertyOwnerAddr) public {
        _addPropertyToRentalMapping(propertyAddr, propertyOwnerAddr);
    }

    function removeProperty(address propertyAddr) public {
        _removePropertyToRentalMapping(propertyAddr);
    }

    function _getProperty(address propertyAddr) internal view isInStorage(propertyAddr) returns (MappingDataTypes.Property storage) {
        uint256 index = propertyAddressToPropertiesForRentIndex[propertyAddr].value;
        return propertiesForRent[index];
    }

    function getProperty(address propertyAddr) public view isInStorage(propertyAddr) returns (MappingDataTypes.Property memory) {
        uint256 index = propertyAddressToPropertiesForRentIndex[propertyAddr].value;
        return propertiesForRent[index];
    }

    function getPropertyOriginalOwner(address propertyAddr) public view isInStorage(propertyAddr) returns (address){
        MappingDataTypes.AddressMappingValue memory property = propertyAddressToOriginalOwner[propertyAddr];
        return property.value;
    }

    function listPropertyForRent(address propertyAddr) isInStorage(propertyAddr) isReadyForRent(propertyAddr) public {
        MappingDataTypes.Property storage property = _getProperty(propertyAddr);
        // list property for rent
        property.status = MappingDataTypes.PropertyStatus.LISTED_FOR_RENT;
        // are resets below needed?
        property.selectedApplicant.isSet = false;
        property.applicantSelectTime = 0;
        property.rentStartTime = 0;
    }

    function rentProperty(address propertyAddr) public isInStorage(propertyAddr) isAwaitingPayment(propertyAddr) {
        MappingDataTypes.Property storage property = _getProperty(propertyAddr);
        property.status = MappingDataTypes.PropertyStatus.RENTED;
    }

    function setPropertyMonthlyRentalPrice(address propertyAddr, uint256 priceInWei) public {
        MappingDataTypes.Property storage property = _getProperty(propertyAddr);

        if (property.status == MappingDataTypes.PropertyStatus.AWAITING_PRICE) {
            // no limitations, set the price and mark the property as ready for rent
            property.monthlyPriceInWei = priceInWei;
            property.status = MappingDataTypes.PropertyStatus.READY_FOR_RENT;
        } else if (property.status == MappingDataTypes.PropertyStatus.RENTED) {
            // TODO: ensure that new price is only sent for 3 months from now on
        } else {
            string memory errorMessage = string.concat("Setting price is not allowed when the property is in the '", propertyStatusToString[property.status] , "' state.");
            revert(errorMessage);
        }
    }

    // applicant applies to rent a property
    function applyForRent(address propertyAddr, address applicantAddr) isInStorage(propertyAddr) isListedForRent(propertyAddr) notYetApplied(propertyAddr, applicantAddr) public {
        MappingDataTypes.PropertyApplicant memory propertyApplicant = MappingDataTypes.PropertyApplicant(applicantAddr, block.timestamp, true);
        propertyApplicants[propertyAddr].push(propertyApplicant);
        uint256 elemIndex = propertyApplicants[propertyAddr].length - 1;
        propertyAddressToPropertyAppplicantsIndex[propertyAddr][applicantAddr] = MappingDataTypes.UintMappingValue(elemIndex, true);
        applicantAddrToPropertyApplicant[propertyAddr][applicantAddr] = propertyApplicant;
    }

    // landlord selects the applicant. from here on, the applicant has X period of time to make a payment
    function selectApplicant(address propertyAddr, address applicantAddr) isInStorage(propertyAddr) isListedForRent(propertyAddr) hasApplicantApplied(propertyAddr, applicantAddr) public {
            MappingDataTypes.Property storage property = _getProperty(propertyAddr);
            MappingDataTypes.PropertyApplicant storage selectedPropertyApplicant = applicantAddrToPropertyApplicant[propertyAddr][applicantAddr];
            property.applicantSelectTime = block.timestamp;
            property.status = MappingDataTypes.PropertyStatus.AWAITING_PAYMENT;
            property.selectedApplicant = selectedPropertyApplicant;
    }
}