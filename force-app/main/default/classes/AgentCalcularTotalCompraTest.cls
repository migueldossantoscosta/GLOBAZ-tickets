@isTest
private class AgentCalcularTotalCompraTest {
    @isTest
    static void testCalcularTotal() {
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev = AgentTestDataFactory.createEvento(promotor.Id);

        AgentCalcularTotalCompra.Input inp = new AgentCalcularTotalCompra.Input();
        inp.eventoId = ev.Id;
        inp.tipoBilhete = 'VIP';
        inp.quantidade = 2;
        inp.extrasJson = '[{"nome":"Bebida","preco":5.00,"qty":1}]';

        Test.startTest();
        List<AgentCalcularTotalCompra.Output> results = AgentCalcularTotalCompra.calcularTotal(new List<AgentCalcularTotalCompra.Input>{inp});
        Test.stopTest();

        Assert.isFalse(results.isEmpty(), 'Deveria retornar resultados');
        Assert.isNull(results[0].erroMsg, 'Mensagem de erro: ' + results[0].erroMsg);
        Assert.isNotNull(results[0].totalComIva, 'Total deve ser calculado');
        Assert.isTrue(results[0].resumoChat.contains('🛒'), 'Deveria conter emoji de carrinho no resumo');
        Assert.isTrue(results[0].resumoChat.contains('VIP'), 'Resumo deveria mencionar o tipo de bilhete');
    }

    @isTest
    static void testCalcularTotalGeralFallback() {
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev = AgentTestDataFactory.createEvento(promotor.Id);
        ev.Pricebook__c = null;
        update ev;

        AgentCalcularTotalCompra.Input inp = new AgentCalcularTotalCompra.Input();
        inp.eventoId = ev.Id;
        inp.tipoBilhete = 'Geral';
        inp.quantidade = 1;

        Test.startTest();
        List<AgentCalcularTotalCompra.Output> results = AgentCalcularTotalCompra.calcularTotal(new List<AgentCalcularTotalCompra.Input>{inp});
        Test.stopTest();

        Assert.isNotNull(results[0].totalComIva, 'Deveria calcular total mesmo sem pricebook');
    }

    @isTest
    static void testCalcularTotalError() {
        AgentCalcularTotalCompra.Input inp = new AgentCalcularTotalCompra.Input();
        inp.eventoId = 'invalid_id';
        inp.tipoBilhete = 'VIP';
        inp.quantidade = 2;

        Test.startTest();
        List<AgentCalcularTotalCompra.Output> results = AgentCalcularTotalCompra.calcularTotal(new List<AgentCalcularTotalCompra.Input>{inp});
        Test.stopTest();

        Assert.isNotNull(results[0].erroMsg, 'Deveria retornar erro para ID inválido');
    }
}