@isTest
public class AgentCriarReservaAgentTest {
    @isTest
    static void testCriarReservaSucesso() {
        Account acc = AgentTestDataFactory.createPersonAccount();
        Evento__c ev = AgentTestDataFactory.createEvento();
        
        Test.setMock(HttpCalloutMock.class, new AgentHttpCalloutMock());
        
        AgentCriarReservaAgent.Input inp = new AgentCriarReservaAgent.Input();
        inp.eventoId = ev.Id;
        inp.accountId = acc.Id;
        inp.metodoPagamento = 'MBWay';
        
        Test.startTest();
        List<AgentCriarReservaAgent.Output> outputs = AgentCriarReservaAgent.criarReserva(new List<AgentCriarReservaAgent.Input>{inp});
        Test.stopTest();
        
        Assert.isTrue(outputs[0].sucesso);
        Assert.isNotNull(outputs[0].orderId);
    }
}
