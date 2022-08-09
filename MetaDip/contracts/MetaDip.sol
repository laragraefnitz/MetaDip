// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./@openzeppelin/contracts@4.6.0/token/ERC721/ERC721.sol";
import "./@openzeppelin/contracts@4.6.0/security/Pausable.sol";
import "./@openzeppelin/contracts@4.6.0/access/Ownable.sol";
import "./@openzeppelin/contracts@4.6.0/utils/Strings.sol";

contract MetaDipToken is ERC721, Pausable, Ownable {
    // ===== STRUCTS ===== //

    struct CertificateInformation{
      string _studentNameInitials; //Initials of first name and last name, for privacy reasons
      string _gpa;
      string _university;
      string _academicTitle;
    }

    // ===== CONSTRUCTOR ===== //

    constructor(string memory _university) ERC721("MetaDip", "mtaDPLM") {
      CERTIFICATE_PRICE = 1 ether; //just for demonstration
      _certificateBaseURI = "ipfs://"; 
      _owner = msg.sender;
      UNIVERSITY = _university;
    }

    // ===== RECEIVE ===== //

    receive() external payable{
      emit Log("receive", msg.value, msg.sender, "");
    }

    // ===== FALLBACK ===== //

    fallback() external payable{}

    function getBalance() public view returns (uint256){
      return address(this).balance;
    }

   // ===== VARIABLES ===== //

    uint256 CERTIFICATE_PRICE; 
    string public _certificateBaseURI;
    string public UNIVERSITY;
    address private _owner;
    
    // ===== EVENTS ===== //

    event NewCertificateIssued(
      address _student, 
      string _academicTitle, 
      string _cid
      );  //once a Certificate has been issued

    event NewCertificateRequested(
      address _student, 
      address _university
      ); //once a Certificate has been Requested 

    event ETHTransaction(
      uint256 _amount, 
      address _from, 
      address _to
      ); //once a Transaction has been made

    event Log(
      string _function, 
      uint _value, 
      address _sender, 
      bytes _data
      ); //"Receive Ether" event

    // ===== MAPPING ===== //

    mapping (address => bool) acceptedRequests; //true if student has succesfully requested a Certificate
    mapping (address => mapping(uint8 => CertificateInformation)) dipContent; //dipContent[student][0] would be students first diploma
    mapping (address => uint8) numberOfDiplomas; //stores information about issued diplomas by this university
    mapping (address => bool) certificateAvailable; //true when one or more certificates are available
    mapping (address => mapping(uint8 => string)) cid; //stores cid of student diplomas

// ===== PUBLIC ===== //

    // ===== 1. GETTER ===== //

    //returns the University Name
    function getUniversity() public view returns (string memory){
      return UNIVERSITY;
    }

    //returns Contract Address
    function getContractAddress() public view returns (address){
      return address(this);
    }

    //returns Token URI of specific certificate number
    function getTokenURI(
      address student, 
      uint8 certNumber
      ) public view returns (string memory){
      require(certificateAvailable[student] == true, "No token available.");
      string memory tkId = cid[student][certNumber];
      return tokenURI(tkId);
    }

    //returns, if request has been accepted for address
    function getAcceptedRequests(
      address student
      ) public view returns(bool){
      if(acceptedRequests[student]==true){
        return true;
        } else{
          return false;
          }
    }

    //returns, if Certificate is available for address
    function getCertificateAvailable(
      address student
      ) public view returns(bool){
      if(certificateAvailable[student] == true){
        return true;
        } else{
          return false;
          }
    }

    //returns Price of a Certificate
    function getPrice() public view whenNotPaused returns(string memory, string memory){
      return("Price in Wei", Strings.toString(CERTIFICATE_PRICE));
    }

    // ===== 2. SEND ETHER ===== //

      function sendViaTransfer(
        address payable _to, 
        uint _amount
        ) public payable returns(bool){
        _to.transfer(_amount);
        return true;
      }

    // ===== 3. REQUESTS ===== //

    //Students can request their Certificates here
    function requestCertificate() public payable whenNotPaused {
      require(msg.value == CERTIFICATE_PRICE, "Not the right amount of ether (ETH) transfered.");
      sendViaTransfer(payable(_owner), msg.value);

      if(certificateAvailable[msg.sender] == false){
        numberOfDiplomas[msg.sender] = 0;
        }

      acceptedRequests[msg.sender] = true; 
      emit NewCertificateRequested(msg.sender, owner());
      emit ETHTransaction(msg.value, msg.sender, owner());
    }

    //employees and/or other Universities can check if students certificate is legit 
    function requestVerification(
      address _studentAddress
      ) public view returns(string memory, string memory, string memory){
      require(certificateAvailable[_studentAddress]==true, "There is NO diploma available!");
      uint8 number = numberOfDiplomas[_studentAddress];
      
      return ("Returning number of Diplomas & the most recent one.", Strings.toString(numberOfDiplomas[_studentAddress]), getTokenURI(_studentAddress, number));
    }

// ===== ONLY OWNER ===== //

    // ===== 1. EXTERNAL ===== //

    function withdraw (
      uint _amount
      ) external onlyOwner {
      require(_amount <= getContractBalance(), "Not possible to withdraw more ETH than available.");
      payable(_owner).transfer(_amount);
      emit ETHTransaction(_amount, msg.sender, _owner);

    }

    function withdrawAll () external onlyOwner {
      payable(_owner).transfer(address(this).balance);
      emit ETHTransaction(address(this).balance, msg.sender, _owner);
    }

    // ===== 2. PUBLIC ===== //
    //Owner cann call dipContent information
    function getCertificateInformation(
      address _student, 
      uint8 _certNumb
      ) public view onlyOwner returns(CertificateInformation memory){
      require(certificateAvailable[_student]==true, "There is no Diploma available.");
      
      return dipContent[_student][_certNumb];
    }

    //Owner can check, if students request has been accepted
    function checkCertificateRequests(
      address _studentAddress
      ) public view whenNotPaused onlyOwner returns(bool){
      if(acceptedRequests[_studentAddress] == true){ 
        return true;
        } else{ 
          return false;
          }
    }

    // ===== 3. MINTING ===== //

    //mints Certificate, requires for the students payment to have gone through
    function createCertificate(
      address _studentAddress, 
      string memory _cid, 
      string memory _studentNameInitials,
      string memory _gpa, 
      string memory _academicTitle
      ) public onlyOwner whenNotPaused{ 
        require(acceptedRequests[_studentAddress]==true, "STUDENT ERROR: Student has not requested the Certificate.");

        //creates new Certificate content for student
        CertificateInformation memory newCert = CertificateInformation(
          _studentNameInitials,
          _gpa, 
          UNIVERSITY, 
          _academicTitle
          );

        numberOfDiplomas[_studentAddress]++;

        //maps students address to content
        dipContent[_studentAddress][numberOfDiplomas[_studentAddress]] = newCert;
        cid[_studentAddress][numberOfDiplomas[_studentAddress]] = _cid;
        //marks student address as true
        certificateAvailable[_studentAddress] = true;

        safeMint(_studentAddress, _cid);
        emit NewCertificateIssued(_studentAddress, _academicTitle, _cid);
        reset_acceptedRequests(_studentAddress);
      }

      function safeMint(
        address to, 
        string memory tokenId
        ) public whenNotPaused onlyOwner {
        //string tokenId = _tokenIdCounter.current(); //sets tokenId to current tokenIdCounter
        //_tokenIdCounter.increment(); //increments tokenIdCounter

        _safeMint(to, tokenId); //NFT is minted to address and tokenId
      }

      // ===== 4. GETTER & SETTER ===== //
      //returns number of certificates an address has
      function getNumberOfDiplomas(
        address _student
        ) public view onlyOwner returns(uint8) {
        return numberOfDiplomas[_student];
      }

      //If Price needs to be adjusted
      function editPrice(
        uint256 _CERTIFICATE_PRICE
        ) public whenNotPaused onlyOwner{
        CERTIFICATE_PRICE = _CERTIFICATE_PRICE;
      }

      function getContractBalance() internal view onlyOwner returns (uint256) {
          return address(this).balance;
      }

      // ===== 5. PAUSABLE ===== //

      function pause() public onlyOwner {
          _pause();
      }

      function unpause() public onlyOwner {
          _unpause();
      }

  // ===== INTERNAL ===== //

    function _baseURI() internal view override returns (string memory){
      return _certificateBaseURI;
    }

    //resets the students address to false, prevents issues when they request another certificate
    function reset_acceptedRequests(
      address _studentAddress
      ) internal 
      {
        require(acceptedRequests[_studentAddress] == true, "ERROR: no Certificate requested.");
        acceptedRequests[_studentAddress] = false;
      }

    function _beforeTokenTransfer(
      address from, 
      address to, 
      string memory tokenId
      ) internal whenNotPaused override 
      {
        super._beforeTokenTransfer(from, to, tokenId);
      }

    }