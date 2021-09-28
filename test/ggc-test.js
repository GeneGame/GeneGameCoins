const { expect } = require('chai')
const { ethers } = require('hardhat')

describe('GeneGameCoin', function () {
  it('Should got GGC as expected', async function () {
    const accounts = await ethers.getSigners()
    const deployer = accounts[0]
    let receiver =  accounts[1]
    let receiver1 =  accounts[2]
    
    // deploy MockToken
    const MockToken = await ethers.getContractFactory('MockToken')
    const mockToken = await MockToken.deploy('10000000000000000000000000')
    await mockToken.deployed()
    
    // deploy GeneGameCoin
    const GeneGameCoin = await ethers.getContractFactory('GeneGameCoin')
    const geneGameCoin = await GeneGameCoin.deploy(
        mockToken.address,
        '1000000000000000', // 1 MTN = 1000 GGC
        '500000',           // 5/1000 for fee        
    )
    await geneGameCoin.deployed()

    expect(await geneGameCoin.collateralNeeded(10000)).to.equal('10050000000000000000')
    // cannot mint before approve
    await expect(geneGameCoin.mint(deployer.address, 10000)).to.be.reverted
    // can mint after approve
    const approveTx = await mockToken.approve(geneGameCoin.address, '10000000000000000000000000')
    await approveTx.wait()
    await expect(geneGameCoin.mint(deployer.address, 10000)).to.not.be.reverted
    // check balance
    expect(await geneGameCoin.balanceOf(deployer.address)).to.equal(10000)
    // burn
    await expect(geneGameCoin.burn(1000)).to.not.be.reverted
    expect(await geneGameCoin.balanceOf(deployer.address)).to.equal(9000)
    // updateReceiver
    const updateReceiverTx = await geneGameCoin.updateReceiver(receiver.address)
    await updateReceiverTx.wait()
    expect(await geneGameCoin.feeReceiver()).to.equal(receiver.address)
    await geneGameCoin.mint(deployer.address, 10000)
    expect(await mockToken.balanceOf(receiver.address)).to.equal('50000000000000000')
    await expect(geneGameCoin.updateReceiver(deployer.address)).to.be.reverted
    await expect(geneGameCoin.connect(receiver).updateReceiver(deployer.address)).to.not.be.reverted
    // updateFeeRate
    // fee rate too large
    await expect(geneGameCoin.updateFeeRate('5000001')).to.be.reverted
    await expect(geneGameCoin.updateFeeRate('5000000')).to.not.be.reverted
    // check fee got with new rate
    await expect(geneGameCoin.updateReceiver(receiver1.address)).to.not.be.reverted
    await expect(geneGameCoin.mint(deployer.address, 10000)).to.not.be.reverted
    expect(await mockToken.balanceOf(receiver1.address)).to.equal('500000000000000000')
  })
})
