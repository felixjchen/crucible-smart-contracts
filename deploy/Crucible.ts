import assert from 'assert'
import { utils } from 'ethers'

import { type DeployFunction } from 'hardhat-deploy/types'

const contractName = 'Crucible'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    const { deployer, endpointv2 } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')
    assert(endpointv2, 'Missing named endpointv2 account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)
    console.log(`EndpointV2: ${endpointv2}`)

    const { address: nuggetSpecLibAddr } = await deploy('NuggetSpecLib', {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: false,
        deterministicDeployment: utils.id('NuggetSpecLib'),
    })
    await hre.run('verify:verify', {
        address: nuggetSpecLibAddr,
        constructorArguments: [],
    })

    const { address: ingotSpecLibAddr } = await deploy('IngotSpecLib', {
        from: deployer,
        log: true,
        libraries: {
            NuggetSpecLib: nuggetSpecLibAddr,
        },
        skipIfAlreadyDeployed: false,
        deterministicDeployment: utils.id('IngotSpecLib'),
    })

    await hre.run('verify:verify', {
        address: ingotSpecLibAddr,
        constructorArguments: [],
        libraries: {
            NuggetSpecLib: nuggetSpecLibAddr,
        },
    })

    const { address: feeAddress } = await deploy('NativeFixedFeeCalculator', {
        from: deployer,
        args: [0, 0, 0],
        log: true,
        skipIfAlreadyDeployed: false,
        deterministicDeployment: utils.id('NativeFixedFeeCalculator'),
    })
    await hre.run('verify:verify', {
        address: feeAddress,
        constructorArguments: [0, 0, 0],
    })

    const { address } = await deploy(contractName, {
        from: deployer,
        args: [endpointv2, deployer, feeAddress, deployer],
        libraries: {
            IngotSpecLib: ingotSpecLibAddr,
        },
        log: true,
        skipIfAlreadyDeployed: false,
        deterministicDeployment: utils.id(contractName),
    })
    await hre.run('verify:verify', {
        address: address,
        constructorArguments: [endpointv2, deployer, feeAddress, deployer],
        libraries: {
            IngotSpecLib: ingotSpecLibAddr,
        },
    })
    console.log(`NuggetSpecLib deployed at: ${nuggetSpecLibAddr}`)
    console.log(`IngotSpecLib deployed at: ${ingotSpecLibAddr}`)
    console.log(`Fee calculator deployed at: ${feeAddress}`)
    console.log(`Crucible contract: ${contractName}, network: ${hre.network.name}, address: ${address}`)
}

deploy.tags = [contractName]

export default deploy
