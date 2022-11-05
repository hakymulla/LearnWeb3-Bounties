// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.7;

contract Distribute {
    address[] public addressess = [address(0)];

    struct NextOfKin {
        address add;
        uint256 percentage;
        bool isRealeased;
    }

    mapping(address => uint256) public guardians;
    mapping(address => uint256) public guardiansFixed;
    mapping(address => NextOfKin[]) public nextofkins;
    mapping(address => address) public nextofkinsToGuardians;
    mapping(address => uint256) public guardiansCheckIn;

    constructor() {}

    function getTime() public view returns (uint256) {
        return block.timestamp;
    }

    function sendValue() public payable {
        (bool sent, ) = address(this).call{value: msg.value}("");
        require(sent, "Failed to send Ether");
        guardians[msg.sender] += msg.value;
        guardiansFixed[msg.sender] += msg.value;
    }

    receive() external payable {}

    function getTotalDonations() public view returns (uint256) {
        return address(this).balance;
    }

    function addNextOfKin(address _kinAdrress, uint256 _percentage) public {
        // _addedTime is in seconds
        NextOfKin memory nextofkin;
        nextofkin.add = _kinAdrress;
        nextofkin.percentage = _percentage;
        nextofkins[msg.sender].push(nextofkin);
        nextofkinsToGuardians[_kinAdrress] = msg.sender;
        guardiansCheckIn[msg.sender] = block.timestamp + 20;
    }

    function showNextOfKin()
        public
        view
        returns (
            address[] memory,
            uint256[] memory,
            bool[] memory
        )
    {
        NextOfKin[] storage next = nextofkins[msg.sender];
        uint256 msgCount = next.length;
        address[] memory add = new address[](msgCount);
        uint256[] memory percentage = new uint256[](msgCount);
        bool[] memory isRealeased = new bool[](msgCount);
        for (uint256 i = 0; i < msgCount; i++) {
            NextOfKin storage message = next[i];
            add[i] = message.add;
            percentage[i] = message.percentage;
            isRealeased[i] = message.isRealeased;
        }
        return (add, percentage, isRealeased);
    }

    function deleteNextOfKin(address _kinAdrress) public {
        NextOfKin[] storage next = nextofkins[msg.sender];
        uint256 msgCount = next.length;
        for (uint256 i = 0; i < msgCount; i++) {
            NextOfKin storage message = next[i];
            if (message.add == _kinAdrress) {
                delete next[i];
                break;
            }
        }
    }

    function editNextOfKinPercentage(address _kinAdrress, uint256 _percentage)
        public
    {
        NextOfKin[] storage next = nextofkins[msg.sender];
        uint256 msgCount = next.length;
        for (uint256 i = 0; i < msgCount; i++) {
            NextOfKin storage message = next[i];
            if (message.add == _kinAdrress) {
                next[i].percentage = _percentage;
                break;
            }
        }
    }

    function guardianWithDraw(uint256 _value) public {
        require(_value <= getTotalDonations());
        require(
            (guardians[msg.sender] > 0) && (guardians[msg.sender] <= _value),
            "You're Not Allowed"
        );
        guardians[msg.sender] -= _value;
        guardiansFixed[msg.sender] -= _value;
        payable(msg.sender).transfer(_value);
    }

    function incrementTime(uint256 _addedTime) private view returns (uint256) {
        uint256 _end = block.timestamp + _addedTime;
        return _end;
    }

    function checkIn(uint256 _addedTime) public {
        require((guardians[msg.sender] > 0), "You're Not Allowed");
        guardiansCheckIn[msg.sender] = incrementTime(_addedTime);
    }

    function nexfOfKinWithDraw() public {
        require(
            nextofkinsToGuardians[msg.sender] != address(0),
            "You're Not Registered"
        );
        address guardian = nextofkinsToGuardians[msg.sender];
        uint256 guardiansBalance = guardians[guardian];
        uint256 guardiansFixedeBalance = guardiansFixed[guardian];

        require(guardiansBalance > 0, "Guardian has no Money");
        require(block.timestamp > guardiansCheckIn[guardian]);
        NextOfKin[] storage next = nextofkins[guardian];
        uint256 msgCount = next.length;
        for (uint256 i = 0; i < msgCount; i++) {
            NextOfKin storage message = next[i];
            if (message.add == msg.sender) {
                require(message.isRealeased == false, "Already Released");
                uint256 distributed_balance = (guardiansFixedeBalance *
                    message.percentage) / 100;
                guardians[guardian] -= distributed_balance;
                message.isRealeased = true;
                payable(msg.sender).transfer(distributed_balance);
                break;
            }
        }
    }
}
