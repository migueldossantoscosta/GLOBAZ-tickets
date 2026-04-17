@isTest
private class AgentVerBilhetesUtilizadorTest {
    @isTest
    static void testVerBilhetes() {
        Account acc = AgentTestDataFactory.createPersonAccount();
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev = AgentTestDataFactory.createEvento(promotor.Id);
        
        Bilhete__c b = new Bilhete__c(
            Account__c = acc.Id,
            Evento__c = ev.Id,
            Fila__c = 'A',
            NumeroLugar__c = 10,
            EstadoBilhete__c = 'Vendido'
        );
        insert b;

        AgentVerBilhetesUtilizador.Input inp = new AgentVerBilhetesUtilizador.Input();
        inp.accountId = acc.Id;

        Test.startTest();
        List<AgentVerBilhetesUtilizador.Output> results = AgentVerBilhetesUtilizador.verBilhetes(new List<AgentVerBilhetesUtilizador.Input>{inp});
        Test.stopTest();

        Assert.isTrue(results[0].temBilhetes, 'Deveria encontrar bilhetes');
        Assert.areEqual(1, results[0].totalBilhetes);
        Assert.isTrue(results[0].mensagemChat.contains(ev.Name));
    }

    @isTest
    static void testVerBilhetesEmpty() {
        Account acc = AgentTestDataFactory.createPersonAccount();
        
        AgentVerBilhetesUtilizador.Input inp = new AgentVerBilhetesUtilizador.Input();
        inp.accountId = acc.Id;

        Test.startTest();
        List<AgentVerBilhetesUtilizador.Output> results = AgentVerBilhetesUtilizador.verBilhetes(new List<AgentVerBilhetesUtilizador.Input>{inp});
        Test.stopTest();

        Assert.isFalse(results[0].temBilhetes);
        Assert.isTrue(results[0].mensagemChat.contains('Não tens bilhetes'));
    }
}