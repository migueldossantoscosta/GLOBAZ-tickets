@isTest
private class AgentPesquisarEventosTest {
    @isTest
    static void testPesquisarEventos() {
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev = AgentTestDataFactory.createEvento(promotor.Id);
        ev.EstadoEvento__c = 'Ativo';
        update ev;

        AgentPesquisarEventos.Input inp = new AgentPesquisarEventos.Input();
        inp.nomeEvento = 'Evento';

        Test.startTest();
        List<AgentPesquisarEventos.Output> results = AgentPesquisarEventos.pesquisarEventos(new List<AgentPesquisarEventos.Input>{inp});
        Test.stopTest();

        Assert.isTrue(results[0].totalEventos >= 1, 'Deveria encontrar pelo menos um evento');
        Assert.isNotNull(results[0].eventosJson);
        Assert.isNotNull(results[0].mensagemChat);
    }

    @isTest
    static void testPesquisarEventosNoResults() {
        AgentPesquisarEventos.Input inp = new AgentPesquisarEventos.Input();
        inp.nomeEvento = 'Non Existent Event';

        Test.startTest();
        List<AgentPesquisarEventos.Output> results = AgentPesquisarEventos.pesquisarEventos(new List<AgentPesquisarEventos.Input>{inp});
        Test.stopTest();

        Assert.areEqual(0, results[0].totalEventos);
        Assert.isTrue(results[0].mensagemChat.contains('não encontrei nenhum evento'));
    }
}