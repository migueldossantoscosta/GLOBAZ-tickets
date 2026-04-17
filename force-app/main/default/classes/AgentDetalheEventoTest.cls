@isTest
private class AgentDetalheEventoTest {
    @isTest
    static void testObterDetalhe() {
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev = AgentTestDataFactory.createEvento(promotor.Id);
        ev.CapacidadeMaxima__c = 100;
        update ev;

        AgentDetalheEvento.Input inp = new AgentDetalheEvento.Input();
        inp.eventoId = ev.Id;

        Test.startTest();
        List<AgentDetalheEvento.Output> results = AgentDetalheEvento.obterDetalhe(new List<AgentDetalheEvento.Input>{inp});
        Test.stopTest();

        Assert.isNotNull(results[0].nomeEvento);
        Assert.areEqual(ev.Id, (Id)results[0].eventoIdOut);
        Assert.isTrue(results[0].precoGeral > 0);
        Assert.areEqual(100, results[0].capacidadeMaxima);
    }

    @isTest
    static void testObterDetalheNotFound() {
        AgentDetalheEvento.Input inp = new AgentDetalheEvento.Input();
        inp.eventoId = null; // Should trigger exception or empty results handling

        Test.startTest();
        List<AgentDetalheEvento.Output> results = AgentDetalheEvento.obterDetalhe(new List<AgentDetalheEvento.Input>{inp});
        Test.stopTest();

        Assert.isNotNull(results[0].erroMsg);
    }
}