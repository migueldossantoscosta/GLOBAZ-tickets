@isTest
private class AgentReenviarBilhetePDFTest {
    @isTest
    static void testReenviarBilhete() {
        Account acc = AgentTestDataFactory.createPersonAccount();
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev = AgentTestDataFactory.createEvento(promotor.Id);
        
        Bilhete__c b = new Bilhete__c(
            Account__c = acc.Id,
            Evento__c = ev.Id,
            EstadoBilhete__c = 'Vendido'
        );
        insert b;

        AgentReenviarBilhetePDF.Input inp = new AgentReenviarBilhetePDF.Input();
        inp.bilheteId = b.Id;
        inp.accountId = acc.Id;

        Test.startTest();
        List<AgentReenviarBilhetePDF.Output> results = AgentReenviarBilhetePDF.reenviarBilhete(new List<AgentReenviarBilhetePDF.Input>{inp});
        Test.stopTest();

        Assert.isTrue(results[0].sucesso, 'Deveria reenviar o bilhete');
        Assert.areEqual(acc.PersonEmail, results[0].emailEnviado);
    }

    @isTest
    static void testReenviarBilheteWrongAccount() {
        Account acc = AgentTestDataFactory.createPersonAccount();
        Account otherAcc = AgentTestDataFactory.createPersonAccount();
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev = AgentTestDataFactory.createEvento(promotor.Id);
        
        Bilhete__c b = new Bilhete__c(
            Account__c = acc.Id,
            Evento__c = ev.Id,
            EstadoBilhete__c = 'Vendido'
        );
        insert b;

        AgentReenviarBilhetePDF.Input inp = new AgentReenviarBilhetePDF.Input();
        inp.bilheteId = b.Id;
        inp.accountId = otherAcc.Id;

        Test.startTest();
        List<AgentReenviarBilhetePDF.Output> results = AgentReenviarBilhetePDF.reenviarBilhete(new List<AgentReenviarBilhetePDF.Input>{inp});
        Test.stopTest();

        Assert.isFalse(results[0].sucesso, 'Não deveria permitir enviar bilhete de outra conta');
    }
}