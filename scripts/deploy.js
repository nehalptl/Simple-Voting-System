const hre = require("hardhat");

async function main() {
  console.log("Deploying SimpleVoting contract...");

  const SimpleVoting = await hre.ethers.getContractFactory("SimpleVoting");
  const simpleVoting = await SimpleVoting.deploy();

  await simpleVoting.deployed();

  console.log(`SimpleVoting deployed to: ${simpleVoting.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
