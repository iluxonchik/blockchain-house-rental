//SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./PropertyRentalStorage.sol";
import {MappingDataTypes} from "./PropertyRentalStorage.sol";

/* Rental procedure:
1. Approve RentalAgreement contract to transfer the token
2. RentalAgreement transfers the token into its possession

From this point forward, the house is listed for rental and registered with the system (i.e. this smart contract).
Ensuring that the house is in the possession of the RentalAgreement contract will ensure that it is not sold, or if a
sale does happen, it will happen under the rules defined in the RentalAgreement. For example, the RentalAgreement may
define that in the scenario of a sale, the Tenant will have 3 months to move out. In this situation, the transfer
of the token representing the house will be delayed until those 3 months pass.

The general process from here on is as follows:

1. The Landlord will set the monthly price of the rental, after that is done, the Landlord can set the house as open
for offers
2. Tenants will apply to rent the house, by calling a function. Their address will get registered in the application
list.
3. The Landlord will review the applicants, and approve one of them. The approved applicant must have applied first.
This represents the signature of the rental agreement from the Landlord's side.
4. The applicant will have X period of time to sign the rental agreement from their side, which consists in transferring
the monthly payment. Once that is done, the applicant becomes a Tenant. If the applicant fails to transfer the funds,
at any point after X days, the Landlord may cancel the agreement with the current applicant and approve a new one. An
SBT is issued to the Tenant, to serve both, as a proof of payment, and history of their good payment practices.
5. The Tenant must transfer the monthly sum by the 7th of every month. If they fail to do so, the Landlord may cancel
the contract. Once a contract is cancelled, a new rental application process may begin. An SBT is issued to the Tenant
indicating that they failed to pay the monthly fee. This information can be later used by Tenants to judge the
quality of the Landlord.
6. If the Landlord wants to increase the price, they must do so with a 3 months notice. An SBT is issued, indicating
that the Landlord increased the price.
7. If the Landlord wants to end the contact with current Tenant, they must do so with a 3 months notice. An SBT is
issued to the Landlord, indicating a termination from their side. This information can e later used by Tenants to judge
the quality of the Landlord.
8. If the Tenant wants to end the contract, they should do so with 3 months in advance. An SBT is issued to the Tenant
and can be used to judge their good behaviour as a rentee.
9. Given that there is no active rental contract, the Landlord may at any point transfer the house token back into their
possession, thus effectively removing the house from the rental market.

When monthly payments are made to the contract, it verifies if the value is enough, and then immediately transfers them
to the Landlord.

This contract will support multiple Landlords posting multiple properties for rent.

Functionality to consider:
* if the Tenant sends more ETH than is required for the monthly payment, the excess will be stored as credit associated
with the Tenant. That credit can be used at any time, either in full or in part to make a monthly payment in the future.
When a rental contract ends, all of the remaining credit will be transferred back to the Tenant.

*/


contract RentalAgreement {
    event PropertyRegisteredForRental(address propertyAddr, address ownerAddr);
    event PropertyListedForRent(address propertyAddr);
    event AppliedForRent(address propertyAddr, address applicantAddr);
    event ApplicantSelected(address propertyAddr, address applicantAddr);
    event PropertyRented(address propertyAddr, address tennatAddr);

    uint8 constant TOKEN_ID = 0;
    PropertyRentalStorage propertyRentalStorage;

    mapping(address => MappingDataTypes.UintMappingValue) tenantCredit;

    modifier isPropertyOwner(address propertyAddr) {
        require(propertyRentalStorage.getPropertyOriginalOwner(propertyAddr) == msg.sender, "Only owner of the proprety can set its monthly rental price.");
        _;
    }
    modifier isPropertyAdded(address propertyAddr) {
        require(propertyRentalStorage.isPropertyAdded(propertyAddr), "Property must be added to set its price.");
        _;
    }

    modifier isPropertyListedForRent(address propertyAddr) {
        require(propertyRentalStorage.isPropertyListedForRent(propertyAddr), "Property must be listed for rent to apply.");
        _;
    }

    modifier hasApplied(address propertyAddr, address applicantAddr) {
        require(propertyRentalStorage.hasApplied(propertyAddr, applicantAddr), "Address has not applied to rent the property.");
        _;
    }

    modifier isSelectedApplicant(address propertyAddr, address applicant) {
        propertyRentalStorage.isSelectedApplicant(propertyAddr, applicant);
        _;
    }

    constructor() {
        propertyRentalStorage = new PropertyRentalStorage();
        
    }

    // 1. Register a property for rental. This is the first step to do after approving transfer on the ERC-721 (landlord)
    function registerPropertyForRental(address propertyAddr) public {
        IERC721 propertyERC721 = IERC721(propertyAddr);
        address currentOwner = propertyERC721.ownerOf(TOKEN_ID);

        require(currentOwner != address(this), "Cannot list a property already owned by RentalAgreement. "
        "Please add RentalAgreement to the approved addressed, and call this "
        "function again."
        );

        // attempt to transfer the ownership
        propertyERC721.transferFrom(currentOwner, address(this), TOKEN_ID);

        // add property to list of properties listed for rental
        propertyRentalStorage.addProperty(propertyAddr, currentOwner);
        emit PropertyRegisteredForRental(propertyAddr, currentOwner);
    }

    // 2. Set the monthly rental price for property (landlord)
    function setPropertyMonthlyRentalPrice(address propertyAddr, uint256 priceInWei) public isPropertyAdded(propertyAddr) isPropertyOwner(propertyAddr)  {
        propertyRentalStorage.setPropertyMonthlyRentalPrice(propertyAddr, priceInWei);
    }

    // 3. List property for rent (landlord)
    function listPropertyForRent(address propertyAddr) isPropertyAdded(propertyAddr) isPropertyOwner(propertyAddr) public  {
        propertyRentalStorage.listPropertyForRent(propertyAddr);
        emit PropertyListedForRent(propertyAddr);
    }

    // 4. Apply for rent (tennant)
    function applyForRent(address propertyAddr) isPropertyAdded(propertyAddr) isPropertyListedForRent(propertyAddr) public {
        propertyRentalStorage.applyForRent(propertyAddr, msg.sender);
        emit AppliedForRent(propertyAddr, msg.sender);
    }

    // 5. Select aplicant (landlord)
    function selectApplicant(address propertyAddr, address applicantAddr) isPropertyOwner(propertyAddr) isPropertyAdded(propertyAddr) isPropertyListedForRent(propertyAddr) hasApplied(propertyAddr, applicantAddr) public {
        propertyRentalStorage.selectApplicant(propertyAddr, applicantAddr);
        emit ApplicantSelected(propertyAddr, applicantAddr);
    }

    // 6. Transfer monthly rental price + start rent (tennant)
    function startRent(address propertyAddr) public payable isSelectedApplicant(propertyAddr, msg.sender) {
        MappingDataTypes.Property memory property = propertyRentalStorage.getProperty(propertyAddr);
        uint256 credit = 0;
        if (tenantCredit[msg.sender].isSet) {
            credit = tenantCredit[msg.sender].value;
        }
        uint256 leftover = credit + msg.value - property.monthlyPriceInWei;
        string memory errorMessage = string.concat("Sum of provided Wei with the credit wei is not enough to cover the monthly rent of property.");
        require(leftover >= 0, errorMessage);
        tenantCredit[msg.sender].isSet = true;
        tenantCredit[msg.sender].value += leftover;

        propertyRentalStorage.rentProperty(propertyAddr);
        emit PropertyRented(propertyAddr, msg.sender);
        // TODO: emit SBT
    }
    

}