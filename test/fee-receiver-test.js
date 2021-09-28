const { expect } = require('chai')
const { ethers } = require('hardhat')

describe('FeeReceiver', function () {
  it('Should got FeeReceiver as expected', async function () {
    const accounts = await ethers.getSigners()
    const deployer = accounts[0]
    
    // deploy MockToken
    const MockToken = await ethers.getContractFactory('MockToken')
    const mockToken = await MockToken.deploy('10000000000000000000000000')
    await mockToken.deployed()
    
    // deploy GeneGameCoin
    const GeneGameCoin = await ethers.getContractFactory('GeneGameCoin')
    const geneGameCoin = await GeneGameCoin.deploy(
        mockToken.address,
        '1000000000000000', // 1 MTN = 1000 GGC
        '1000000',          // 1/100 for fee        
    )
    await geneGameCoin.deployed()

    // deploy FeeReceiver
    const FeeReceiver = await ethers.getContractFactory('FeeReceiver')
    const feeReceiver = await FeeReceiver.deploy(
        geneGameCoin.address, // GGC
        [
            accounts[1].address, 
            accounts[2].address,
        ],
        [
            200000, // 20%
            800000, // 80%
        ],
    )
    await feeReceiver.deployed()

    await expect(geneGameCoin.updateReceiver(feeReceiver.address)).to.not.be.reverted
    await expect(mockToken.approve(geneGameCoin.address, '10000000000000000000000000')).to.not.be.reverted
    
    // check fee amount
    await expect(geneGameCoin.mint(deployer.address, 10000)).to.not.be.reverted
    expect(await mockToken.balanceOf(feeReceiver.address)).to.equal('100000000000000000')

    // check redeem
    await expect(feeReceiver.redeemAll(accounts[1].address)).to.be.reverted
    await expect(feeReceiver.connect(accounts[1]).redeemAll(accounts[1].address)).to.not.be.reverted
    expect(await mockToken.balanceOf(accounts[1].address)).to.equal('20000000000000000')
    await feeReceiver.connect(accounts[2]).redeemAll(accounts[2].address)
    await expect(feeReceiver.connect(accounts[2]).redeemAll(accounts[2].address)).to.not.be.reverted
    expect(await mockToken.balanceOf(accounts[2].address)).to.equal('80000000000000000')

    // check receiver update
    expect(await geneGameCoin.feeReceiver()).to.equal(feeReceiver.address)
    await expect(feeReceiver.connect(accounts[1]).proposeToUpdateReceiver(accounts[3].address)).to.not.be.reverted
    expect(await geneGameCoin.feeReceiver()).to.equal(feeReceiver.address)
    await expect(feeReceiver.connect(accounts[2]).proposeToUpdateReceiver(accounts[4].address)).to.not.be.reverted
    expect(await geneGameCoin.feeReceiver()).to.equal(feeReceiver.address)
    await expect(feeReceiver.connect(accounts[2]).proposeToUpdateReceiver(accounts[3].address)).to.not.be.reverted
    expect(await geneGameCoin.feeReceiver()).to.equal(accounts[3].address)
  })
})
