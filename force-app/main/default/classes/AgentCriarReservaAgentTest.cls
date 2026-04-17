@isTest
private class AgentCriarReservaAgentTest {
    @isTest
    static void testCriarReservaSuccess() {
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev = AgentTestDataFactory.createEvento(promotor.Id);
        
        // Mock successful payment callout
        Test.setMock(HttpCalloutMock.class, new AgentTestMock(200, 'OK', '{"status":"success"}'));

        AgentCriarReservaAgent.Input inp = new AgentCriarReservaAgent.Input();
        inp.eventoId = ev.Id;
        inp.metodoPagamento = 'Cartão';
        inp.nomeCompleto = 'Reserva Teste';
        inp.email = 'reserva@test.pt';

        Test.startTest();
        List<AgentCriarReservaAgent.Output> results = AgentCriarReservaAgent.criarReserva(new List<AgentCriarReservaAgent.Input>{inp});
        Test.stopTest();

        Assert.isTrue(results[0].sucesso, 'Deveria criar reserva com sucesso');
        Assert.isNotNull(results[0].orderId, 'Deveria retornar Order ID');
    }

    @isTest
    static void testCriarReservaRecusado() {
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev = AgentTestDataFactory.createEvento(promotor.Id);
        
        // Mock refused payment callout
        Test.setMock(HttpCalloutMock.class, new AgentTestMock(402, 'Refused', '{"status":"refused"}'));

        AgentCriarReservaAgent.Input inp = new AgentCriarReservaAgent.Input();
        inp.eventoId = ev.Id;
        inp.metodoPagamento = 'Cartão';
        inp.nomeCompleto = 'Reserva Falha';
        inp.email = 'fail@test.pt';

        Test.startTest();
        List<AgentCriarReservaAgent.Output> results = AgentCriarReservaAgent.criarReserva(new List<AgentCriarReservaAgent.Input>{inp});
        Test.stopTest();

        Assert.isFalse(results[0].sucesso);
        Assert.areEqual('PAGAMENTO_RECUSADO', results[0].erroMsg);
    }
}