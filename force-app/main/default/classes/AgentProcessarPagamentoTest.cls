@isTest
public class AgentProcessarPagamentoTest {
    @isTest
    static void testProcessarPagamentoSucesso() {
        Account acc = AgentTestDataFactory.createPersonAccount();
        Evento__c ev = AgentTestDataFactory.createEvento();
        Order ord = AgentTestDataFactory.createOrder(acc.Id, ev.Id);
        
        Test.setMock(HttpCalloutMock.class, new AgentHttpCalloutMock());
        
        AgentProcessarPagamento.Input inp = new AgentProcessarPagamento.Input();
        inp.orderId = ord.Id;
        inp.eventoId = ev.Id;
        inp.tipoBilhete = 'Geral';
        inp.quantidade = 1;
        inp.fila = 'A';
        inp.lugar = 1;
        
        Test.startTest();
        List<AgentProcessarPagamento.Output> outputs = AgentProcessarPagamento.processarPagamento(new List<AgentProcessarPagamento.Input>{inp});
        Test.stopTest();
        
        Assert.isTrue(outputs[0].sucesso);
        Assert.areEqual(1, (Integer)outputs[0].totalBilhetes);
        Assert.isNotNull(outputs[0].mensagemChat);
    }
}
