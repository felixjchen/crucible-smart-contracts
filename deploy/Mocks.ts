import assert from 'assert'
import { utils } from 'ethers'

import { type DeployFunction } from 'hardhat-deploy/types'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    const { address: erc20mockAddr } = await deploy('ERC20Mock', {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: false,
        args: ['ERC20Mock', 'ERC20Mock'],
        deterministicDeployment: utils.id('ERC20Mock'),
    })
    await hre.run('verify:verify', {
        address: erc20mockAddr,
        constructorArguments: ['ERC20Mock', 'ERC20Mock'],
    })

    const { address: erc721mockAddr } = await deploy('ERC721Mock', {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: false,
        args: ['ERC721Mock', 'ERC721Mock'],
        deterministicDeployment: utils.id('ERC721Mock'),
    })
    await hre.run('verify:verify', {
        address: erc721mockAddr,
        constructorArguments: ['ERC721Mock', 'ERC721Mock'],
    })

    const { address: erc1155mockAddr } = await deploy('ERC1155Mock', {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: false,
        args: ['ERC1155Mock', 'ERC1155Mock'],
        deterministicDeployment: utils.id('ERC1155Mock'),
    })
    await hre.run('verify:verify', {
        address: erc1155mockAddr,
        constructorArguments: ['ERC1155Mock', 'ERC1155Mock'],
    })

    console.log(`ERC20Mock deployed at: ${erc20mockAddr}`)
    console.log(`ERC721Mock deployed at: ${erc721mockAddr}`)
    console.log(`ERC1155Mock deployed at: ${erc1155mockAddr}`)
}
deploy.tags = ['Mocks']

export default deploy
