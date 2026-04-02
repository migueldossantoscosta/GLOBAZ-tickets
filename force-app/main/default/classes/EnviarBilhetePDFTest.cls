@isTest
public class EnviarBilhetePDFTest {

    @isTest
    static void testEnviarEmailFlow() {
        
        // =========================================================
        // 1. CRIAR DADOS DE TESTE (Simular a base de dados)
        // =========================================================
        
        Recinto__c recinto = new Recinto__c(
            Name = 'Super Bock Arena',
            Cidade__c = 'Porto',
            TipoRecinto__c = 'Arena',         
            CodigoPostal__c = '4000-000',        
            CoordenadasGPS__Latitude__s = 41.14, 
            CoordenadasGPS__Longitude__s = -8.61,
            LotacaoMaxima__c = 10000             
        );
        insert recinto;

        Account promotor = new Account(
            Name = 'Promotor Teste LDA',
            Phone = '213920240',
            Website = 'https://www.teste.pt',
            AnnualRevenue = 30000,
            NIF__c = '123456789',     
            IBAN__c = 'PT50123456789012345678901', 
            TaxaComissao__c = 10     
        );
        insert promotor;

        Account cliente = new Account(
            FirstName = 'João',
            LastName = 'Teste',
            PersonEmail = 'miguelcostinha521@gmail.com',
            Phone = '912345678',
            Website = 'https://www.cliente.pt',
            AnnualRevenue = 1000,
            NIF__c = '250170248', 
            IBAN__c = 'PT50002700000001234567833',
            TaxaComissao__c = 0
        );
        insert cliente;

        Evento__c eventoTeste = new Evento__c(
            Name = 'Concerto de Teste',
            Recinto__c = recinto.Id,
            CategoriaPrincipal__c = 'Concertos/Shows', 
            ClassificacaoEtaria__c = 'M6', 
            EstadoEvento__c = 'Ativo', 
            CapacidadeMaxima__c = 500, 
            TipoEvento__c = 'Culturais e Entretenimento', 
            DuracaoEvento__c = 120, 
            DataFimEvento__c = Date.today().addDays(15),
            DataEvento__c = Date.today().addDays(10)
        );
        insert eventoTeste;
        
        Order encomenda = new Order(
            AccountId = cliente.Id,
            Evento__c = eventoTeste.Id, // <--- O FIX VITAL PARA O FLOW NÃO EXPLODIR!
            EffectiveDate = Date.today(),
            MetodoPagamento__c='MBWay' ,
            GatewayId__c='1234.1234.1235',
            QuantidadeBilhetes__c = 3,
            Status = 'Draft'
        );
        insert encomenda;

        Bilhete__c bilhete = new Bilhete__c(
            Order__c = encomenda.Id,
            Evento__c = eventoTeste.Id,
            Account__c = cliente.Id, 
            Fila__c = 'A',
            NumeroLugar__c = 1
        );
        insert bilhete;
        
        // =========================================================
        // 2. EXECUTAR O TESTE (Simular o Flow)
        // =========================================================
        
        Test.startTest();
        
        List<Id> listaIds = new List<Id>{ bilhete.Id };
        EnviarBilhetePDF.enviarEmailFlow(listaIds);
        
        Test.stopTest();

        // =========================================================
        // 3. VERIFICAR OS RESULTADOS (Asserts)
        // =========================================================
        
        System.assertEquals(1, Limits.getEmailInvocations(), 'O sistema deveria ter processado o envio de 1 email.');
    }
}