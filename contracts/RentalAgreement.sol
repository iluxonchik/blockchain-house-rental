//SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

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

}