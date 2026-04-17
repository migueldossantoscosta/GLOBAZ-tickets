@isTest
private class AgentProcessarPagamentoTest {
    @isTest
    static void testProcessarPagamentoSuccess() {
        Account acc = AgentTestDataFactory.createPersonAccount();
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev = AgentTestDataFactory.createEvento(promotor.Id);
        Order ord = AgentTestDataFactory.createOrder(acc.Id, ev.Id);
        ord.MetodoPagamento__c = 'MBWay';
        update ord;

        Test.setMock(HttpCalloutMock.class, new AgentTestMock(200, 'OK', '{"status":"success"}'));

        AgentProcessarPagamento.Input inp = new AgentProcessarPagamento.Input();
        inp.orderId = ord.Id;
        inp.eventoId = ev.Id;
        inp.tipoBilhete = 'Geral';
        inp.quantidade = 1;
        inp.lugar = 1;

        Test.startTest();
        List<AgentProcessarPagamento.Output> results = AgentProcessarPagamento.processarPagamento(new List<AgentProcessarPagamento.Input>{inp});
        Test.stopTest();

        Assert.isTrue(results[0].sucesso, 'Deveria processar o pagamento');
        Assert.isTrue(results[0].totalBilhetes > 0, 'Deveria criar pelo menos um bilhete');
        Assert.isTrue(results[0].mensagemChat.contains('confirmada'), 'Deveria mostrar mensagem de confirmação');
    }

    @isTest
    static void testProcessarPagamentoFail() {
        Account acc = AgentTestDataFactory.createPersonAccount();
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev = AgentTestDataFactory.createEvento(promotor.Id);
        Order ord = AgentTestDataFactory.createOrder(acc.Id, ev.Id);

        Test.setMock(HttpCalloutMock.class, new AgentTestMock(402, 'Refused', '{"status":"refused"}'));

        AgentProcessarPagamento.Input inp = new AgentProcessarPagamento.Input();
        inp.orderId = ord.Id;
        inp.eventoId = ev.Id;
        inp.tipoBilhete = 'VIP';
        inp.quantidade = 1;

        Test.startTest();
        List<AgentProcessarPagamento.Output> results = AgentProcessarPagamento.processarPagamento(new List<AgentProcessarPagamento.Input>{inp});
        Test.stopTest();

        Assert.isFalse(results[0].sucesso);
        Assert.areEqual('PAGAMENTO_RECUSADO', results[0].erroMsg);
    }
}