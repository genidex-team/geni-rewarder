const data = require('geni_data');

const testTokenList = [
    "0x7036124464A2d2447516309169322c8498ac51e3",
    "0xE7FF84Df24A9a252B6E8A5BB093aC52B1d8bEEdf"
  ];

async function main(){
    var token = await data.getTokenInfo('geni', testTokenList[0]);
    console.log('token', token);

    var tokens = await data.getTokensInfo('geni', testTokenList);
    console.log('tokens', tokens);
}


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
