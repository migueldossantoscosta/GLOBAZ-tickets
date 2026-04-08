@isTest
public class AgentTestDataFactory {
    
    public static Account createPersonAccount() {
        Id paRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND IsPersonType = true LIMIT 1].Id;
        Account acc = new Account(
            FirstName = 'Test',
            LastName = 'User',
            PersonEmail = 'testuser@example.com',
            BillingCity = 'Lisboa',
            Valido__c = true,
            RecordTypeId = paRecordTypeId
        );
        insert acc;
        return acc;
    }

    public static Evento__c createEvento() {
        Pricebook2 pb = new Pricebook2(Name = 'Test Pricebook', IsActive = true);
        insert pb;

        Evento__c ev = new Evento__c(
            Name = 'Test Event',
            DataEvento__c = DateTime.now().addDays(7),
            LocalizacaoEvento__c = 'Lisboa',
            CategoriaPrincipal__c = 'Musica',
            EstadoEvento__c = 'Ativo',
            PrecoBilhete__c = 20.00,
            CapacidadeMaxima__c = 100,
            Pricebook__c = pb.Id
        );
        insert ev;

        Product2 p1 = new Product2(Name = 'Geral', ProductCode = 'BLT-Geral', IsActive = true);
        Product2 p2 = new Product2(Name = 'VIP', ProductCode = 'BLT-VIP', IsActive = true);
        insert new List<Product2>{p1, p2};

        Id standardPbId = Test.getStandardPricebookId();
        PricebookEntry spe1 = new PricebookEntry(Pricebook2Id = standardPbId, Product2Id = p1.Id, UnitPrice = 20.00, IsActive = true);
        PricebookEntry spe2 = new PricebookEntry(Pricebook2Id = standardPbId, Product2Id = p2.Id, UnitPrice = 50.00, IsActive = true);
        insert new List<PricebookEntry>{spe1, spe2};

        PricebookEntry pbe1 = new PricebookEntry(Pricebook2Id = pb.Id, Product2Id = p1.Id, UnitPrice = 20.00, IsActive = true);
        PricebookEntry pbe2 = new PricebookEntry(Pricebook2Id = pb.Id, Product2Id = p2.Id, UnitPrice = 50.00, IsActive = true);
        insert new List<PricebookEntry>{pbe1, pbe2};

        return ev;
    }

    public static Order createOrder(Id accId, Id evId) {
        Order ord = new Order(
            AccountId = accId,
            Evento__c = evId,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            MetodoPagamento__c = 'MBWay'
        );
        insert ord;
        return ord;
    }
}
