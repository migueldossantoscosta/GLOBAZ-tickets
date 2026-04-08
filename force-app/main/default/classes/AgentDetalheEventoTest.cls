@isTest
public class AgentDetalheEventoTest {
    @isTest
    static void testObterDetalheSucesso() {
        Evento__c ev = AgentTestDataFactory.createEvento();
        
        AgentDetalheEvento.Input inp = new AgentDetalheEvento.Input();
        inp.eventoId = ev.Id;
        
        Test.startTest();
        List<AgentDetalheEvento.Output> outputs = AgentDetalheEvento.obterDetalhe(new List<AgentDetalheEvento.Input>{inp});
        Test.stopTest();
        
        Assert.areEqual(ev.Name, outputs[0].nomeEvento);
        Assert.isNotNull(outputs[0].mensagemChat);
    }
    
    @isTest
    static void testObterDetalheErro() {
        AgentDetalheEvento.Input inp = new AgentDetalheEvento.Input();
        inp.eventoId = null;
        
        Test.startTest();
        List<AgentDetalheEvento.Output> outputs = AgentDetalheEvento.obterDetalhe(new List<AgentDetalheEvento.Input>{inp});
        Test.stopTest();
        
        Assert.isNotNull(outputs[0].erroMsg);
    }
}
