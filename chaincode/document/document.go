package main

import (
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// DocumentContract contract untuk manajemen dokumen
type DocumentContract struct {
	contractapi.Contract
}

// Document metadata dokumen yang disimpan di blockchain
type Document struct {
	ID          string `json:"id"`
	FileName    string `json:"fileName"`
	FileHash    string `json:"fileHash"`    // SHA256 hash file asli
	IPFSCID     string `json:"ipfsCID"`     // Content ID di IPFS
	Owner       string `json:"owner"`       // MSP ID pemilik
	CreatedAt   string `json:"createdAt"`
	Encrypted   bool   `json:"encrypted"`   // Apakah file di-encrypt
	Description string `json:"description"`
}

// CreateDocument membuat dokumen baru
func (c *DocumentContract) CreateDocument(ctx contractapi.TransactionContextInterface, id string, fileName string, fileHash string, ipfsCID string, encrypted bool, description string) error {
	// Cek apakah dokumen sudah ada
	exists, err := c.DocumentExists(ctx, id)
	if err != nil {
		return err
	}
	if exists {
		return fmt.Errorf("document %s already exists", id)
	}

	// Dapatkan timestamp
	timestamp, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		return err
	}

	// Dapatkan MSP ID pemilik
	clientMSPID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return err
	}

	// Buat dokumen baru
	doc := Document{
		ID:          id,
		FileName:    fileName,
		FileHash:    fileHash,
		IPFSCID:     ipfsCID,
		Owner:       clientMSPID,
		CreatedAt:   timestamp.AsTime().Format("2006-01-02 15:04:05"),
		Encrypted:   encrypted,
		Description: description,
	}

	// Serialize ke JSON
	docJSON, err := json.Marshal(doc)
	if err != nil {
		return err
	}

	// Simpan ke ledger
	return ctx.GetStub().PutState(id, docJSON)
}

// GetDocument mengambil dokumen berdasarkan ID
func (c *DocumentContract) GetDocument(ctx contractapi.TransactionContextInterface, id string) (*Document, error) {
	docJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, err
	}
	if docJSON == nil {
		return nil, fmt.Errorf("document %s does not exist", id)
	}

	var doc Document
	err = json.Unmarshal(docJSON, &doc)
	if err != nil {
		return nil, err
	}

	return &doc, nil
}

// DocumentExists cek apakah dokumen ada
func (c *DocumentContract) DocumentExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	docJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return false, err
	}
	return docJSON != nil, nil
}

// GetAllDocuments mengambil semua dokumen
func (c *DocumentContract) GetAllDocuments(ctx contractapi.TransactionContextInterface) ([]*Document, error) {
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var documents []*Document
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var doc Document
		err = json.Unmarshal(queryResponse.Value, &doc)
		if err != nil {
			return nil, err
		}
		documents = append(documents, &doc)
	}

	return documents, nil
}

func main() {
	contract := new(DocumentContract)
	cc, err := contractapi.NewChaincode(contract)
	if err != nil {
		panic(fmt.Sprintf("could not create chaincode: %v", err))
	}

	err = cc.Start()
	if err != nil {
		panic(fmt.Sprintf("could not start chaincode: %v", err))
	}
}
