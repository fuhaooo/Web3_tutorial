const { ethers, deployments, getNamedAccounts } = require("hardhat")
const { assert, expect  } = require("chai")
const helpers = require("@nomicfoundation/hardhat-network-helpers")
const { deploymentChains,developmentChains } = require("../../helper-hardhat-config")

developmentChains.includes(network.name)
? describe.skip
: describe("test fundme contract", async function() {
    let fundMe
    let firstAccount
    beforeEach(async function() {
        await deployments.fixture(["all"])
        firstAccount = (await getNamedAccounts()).firstAccount
        const fundMeDeployment = await deployments.get("FundMe")
        fundMe = await ethers.getContractAt("FundMe", fundMeDeployment.address)
    })

    // test fund and getFund seccessfully
    it("fund and getFund successfully",
        async function() {
            // make sure target reached
            await fundMe.fund({value: ethers.parseEther("0.5")})
            // make sure window closed
            await new Promise(resolve => setTimeout(resolve, 301 *1000))
            // make sure we can get receipt
            const getFundTx = await fundMe.getFund()
            const getFundReceipt = await getFundTx.wait()
            expect(getFundReceipt)
                .to.be.emit(fundMe, "FundWithdrawByOwner")
                .withArgs(ethers.parseEther("0.5"))
        }
    )
    // test fund and refund successfully
    it("fund and refund successfully",
        async function() {
            // make sure target reached
            await fundMe.fund({value: ethers.parseEther("0.1")})
            // make sure window closed
            await new Promise(resolve => setTimeout(resolve, 301 *1000))
            // make sure we can get receipt
            const reFundTx = await fundMe.reFund()
            const reFundReceipt = await reFundTx.wait()
            expect(reFundReceipt)
                .to.be.emit(fundMe, "RefundByFunder")
                .withArgs(firstAccount, ethers.parseEther("0.1"))
        }
    )
})
