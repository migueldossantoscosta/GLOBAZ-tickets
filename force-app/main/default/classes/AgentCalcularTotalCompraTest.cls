@isTest
public class AgentCalcularTotalCompraTest {
    @isTest
    static void testCalcularTotalSucesso() {
        Evento__c ev = AgentTestDataFactory.createEvento();
        
        AgentCalcularTotalCompra.Input inp = new AgentCalcularTotalCompra.Input();
        inp.eventoId = ev.Id;
        inp.tipoBilhete = 'Geral';
        inp.quantidade = 2;
        
        Test.startTest();
        List<AgentCalcularTotalCompra.Output> outputs = AgentCalcularTotalCompra.calcularTotal(new List<AgentCalcularTotalCompra.Input>{inp});
        Test.stopTest();
        
        Assert.areEqual(49.20, outputs[0].totalComIva); // (20 * 2) * 1.23 = 49.20
        Assert.isNotNull(outputs[0].resumoChat);
    }
    
    @isTest
    static void testCalcularTotalTipoInexistente() {
        Evento__c ev = AgentTestDataFactory.createEvento();
        
        AgentCalcularTotalCompra.Input inp = new AgentCalcularTotalCompra.Input();
        inp.eventoId = ev.Id;
        inp.tipoBilhete = 'Inexistente';
        inp.quantidade = 1;
        
        Test.startTest();
        List<AgentCalcularTotalCompra.Output> outputs = AgentCalcularTotalCompra.calcularTotal(new List<AgentCalcularTotalCompra.Input>{inp});
        Test.stopTest();
        
        Assert.isNotNull(outputs[0].erroMsg);
    }
}
