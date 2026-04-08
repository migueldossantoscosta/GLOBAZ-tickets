@isTest
public class AgentVerBilhetesUtilizadorTest {
    @isTest
    static void testVerBilhetesSucesso() {
        Account acc = AgentTestDataFactory.createPersonAccount();
        Evento__c ev = AgentTestDataFactory.createEvento();
        Order ord = AgentTestDataFactory.createOrder(acc.Id, ev.Id);
        
        Bilhete__c b = new Bilhete__c(
            Account__c = acc.Id,
            Evento__c = ev.Id,
            Order__c = ord.Id,
            EstadoBilhete__c = 'Vendido',
            Fila__c = 'A',
            NumeroLugar__c = 1
        );
        insert b;
        
        AgentVerBilhetesUtilizador.Input inp = new AgentVerBilhetesUtilizador.Input();
        inp.accountId = acc.Id;
        
        Test.startTest();
        List<AgentVerBilhetesUtilizador.Output> outputs = AgentVerBilhetesUtilizador.verBilhetes(new List<AgentVerBilhetesUtilizador.Input>{inp});
        Test.stopTest();
        
        Assert.isTrue(outputs[0].temBilhetes);
        Assert.areEqual(1, (Integer)outputs[0].totalBilhetes);
        Assert.isNotNull(outputs[0].mensagemChat);
    }
}
