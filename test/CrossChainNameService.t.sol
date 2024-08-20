const { ethers } = require("hardhat");
const { assert } = require("chai");

describe("CrossChainNameService Tests", () => {
    let CCIPLocalSimulator, ccnsLookupSource, ccnsLookupReceiver, ccnsRegister, ccnsReceiver;

    beforeEach(async () => {
        // Deploy CCIPLocalSimulator contract
        const CCIPLocalSimulatorFactory = await ethers.getContractFactory("CCIPLocalSimulator");
        CCIPLocalSimulator = await CCIPLocalSimulatorFactory.deploy();
        await CCIPLocalSimulator.deployed();

        // Fetch configuration details for Chainlink local setup
        const [
            chainSelector,
            sourceRouter,
        ] = await CCIPLocalSimulator.configuration();

        // Deploy CrossChainNameServiceLookup contracts for both source and receiver
        const CrossChainNameServiceLookupFactory = await ethers.getContractFactory("CrossChainNameServiceLookup");
        ccnsLookupSource = await CrossChainNameServiceLookupFactory.deploy();
        await ccnsLookupSource.deployed();

        ccnsLookupReceiver = await CrossChainNameServiceLookupFactory.deploy();
        await ccnsLookupReceiver.deployed();

        // Deploy CrossChainNameServiceRegister contract
        const CrossChainNameServiceRegisterFactory = await ethers.getContractFactory("CrossChainNameServiceRegister");
        ccnsRegister = await CrossChainNameServiceRegisterFactory.deploy(sourceRouter, ccnsLookupSource.address);
        await ccnsRegister.deployed();

        // Deploy CrossChainNameServiceReceiver contract
        const CrossChainNameServiceReceiverFactory = await ethers.getContractFactory("CrossChainNameServiceReceiver");
        ccnsReceiver = await CrossChainNameServiceReceiverFactory.deploy(sourceRouter, ccnsLookupReceiver.address, chainSelector);
        await ccnsReceiver.deployed();

        // Enable the chain in the register contract with a gas limit
        await ccnsRegister.enableChain(chainSelector, ccnsReceiver.address, 500000);

        // Set CrossChainNameService addresses in the lookup contracts
        await ccnsLookupSource.setCrossChainNameServiceAddress(ccnsRegister.address);
        await ccnsLookupReceiver.setCrossChainNameServiceAddress(ccnsReceiver.address);
    });

    it("should register a name and verify it resolves to the correct address", async () => {
        // Retrieve test accounts
        const [_, alice] = await ethers.getSigners();
        
        // Connect Alice's account to the register contract
        const aliceConnectedRegister = ccnsRegister.connect(alice);

        // Register a name for Alice
        await aliceConnectedRegister.register("alice.ccns");

        // Lookup the registered name
        const registeredAddress = await ccnsLookupSource.lookup("alice.ccns");

        // Assert that the registered address matches Alice's address
        assert.equal(registeredAddress, alice.address);
    });
});
