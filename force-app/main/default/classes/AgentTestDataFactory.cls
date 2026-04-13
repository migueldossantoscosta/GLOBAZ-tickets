@isTest
public class AgentTestDataFactory {

    public static Account createPersonAccount() {
        Id personAccountRecordTypeId = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Account' AND IsPersonType = true 
            LIMIT 1
        ].Id;

        Account acc = new Account(
            FirstName = 'Test',
            LastName = 'User',
            PersonEmail = 'testuser@example.com',
            RecordTypeId = personAccountRecordTypeId,
            Valido__c = true
        );
        insert acc;
        return acc;
    }

    public static Account createBusinessAccount() {
        Account acc = new Account(
            Name = 'Promotor Teste',
            Phone = '912345678'
        );
        insert acc;
        return acc;
    }

    public static Recinto__c createRecinto() {
        Recinto__c rec = new Recinto__c(
            Name = 'Recinto de Teste',
            Cidade__c = 'Lisboa',
            MoradaCompleta__c = 'Rua de Teste 123',
            CodigoPostal__c = '1000-001',
            LotacaoMaxima__c = 1000,
            TipoRecinto__c = 'Arena',
            CoordenadasGPS__Latitude__s = 38.71667,
            CoordenadasGPS__Longitude__s = -9.13333,
            Ativo__c = true
        );
        insert rec;
        return rec;
    }

    public static Evento__c createEvento(Id promotorId) {
        Pricebook2 pb = new Pricebook2(Name='Test PB', IsActive=true);
        insert pb;

        Recinto__c rec = createRecinto();

        Evento__c ev = new Evento__c(
            Name = 'Evento de Teste',
            DataEvento__c = System.now().addDays(7),
            DataFimEvento__c = System.now().addDays(7).addHours(2),
            DuracaoEvento__c = 120,
            Recinto__c = rec.Id,
            Destaque__c = true,
            Pricebook__c = pb.Id,
            Account__c = promotorId,
            PrecoBilhete__c = 25.00,
            CapacidadeMaxima__c = 1000,
            CategoriaPrincipal__c = 'Concertos/Shows',
            ClassificacaoEtaria__c = 'M12',
            EstadoEvento__c = 'Ativo',
            TipoEvento__c = 'Culturais e Entretenimento'
        );
        insert ev;

        // Create PricebookEntries
        Product2 pGeral = new Product2(Name='Geral', ProductCode='BLT-Geral', IsActive=true);
        Product2 pVip = new Product2(Name='VIP', ProductCode='BLT-VIP', IsActive=true);
        Product2 pCamarote = new Product2(Name='Camarote', ProductCode='BLT-CAMAROTE', IsActive=true);
        insert new List<Product2>{pGeral, pVip, pCamarote};

        Id stdPbId = Test.getStandardPricebookId();
        
        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id=stdPbId, Product2Id=pGeral.Id, UnitPrice=25.00, IsActive=true),
            new PricebookEntry(Pricebook2Id=stdPbId, Product2Id=pVip.Id, UnitPrice=75.00, IsActive=true),
            new PricebookEntry(Pricebook2Id=stdPbId, Product2Id=pCamarote.Id, UnitPrice=95.00, IsActive=true)
        };

        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id=pb.Id, Product2Id=pGeral.Id, UnitPrice=25.00, IsActive=true),
            new PricebookEntry(Pricebook2Id=pb.Id, Product2Id=pVip.Id, UnitPrice=75.00, IsActive=true),
            new PricebookEntry(Pricebook2Id=pb.Id, Product2Id=pCamarote.Id, UnitPrice=95.00, IsActive=true)
        };

        return ev;
    }

    public static Order createOrder(Id accId, Id evId) {
        Order ord = new Order(
            AccountId = accId,
            Evento__c = evId,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            MetodoPagamento__c = 'Cartão',
            QuantidadeBilhetes__c = 1
        );
        insert ord;
        return ord;
    }
}
