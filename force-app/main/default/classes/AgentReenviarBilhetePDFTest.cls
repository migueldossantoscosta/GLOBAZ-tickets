@isTest
public class AgentReenviarBilhetePDFTest {
    @isTest
    static void testReenviarBilheteSucesso() {
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
        
        AgentReenviarBilhetePDF.Input inp = new AgentReenviarBilhetePDF.Input();
        inp.bilheteId = b.Id;
        inp.accountId = acc.Id;
        
        Test.startTest();
        List<AgentReenviarBilhetePDF.Output> outputs = AgentReenviarBilhetePDF.reenviarBilhete(new List<AgentReenviarBilhetePDF.Input>{inp});
        Test.stopTest();
        
        Assert.isTrue(outputs[0].sucesso);
        Assert.areEqual(acc.PersonEmail, outputs[0].emailEnviado);
    }
}
