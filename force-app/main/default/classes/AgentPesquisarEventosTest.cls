@isTest
public class AgentPesquisarEventosTest {
    @isTest
    static void testPesquisarEventosSucesso() {
        Evento__c ev = AgentTestDataFactory.createEvento();
        
        AgentPesquisarEventos.Input inp = new AgentPesquisarEventos.Input();
        inp.nomeEvento = 'Test';
        
        Test.startTest();
        List<AgentPesquisarEventos.Output> outputs = AgentPesquisarEventos.pesquisarEventos(new List<AgentPesquisarEventos.Input>{inp});
        Test.stopTest();
        
        Assert.areEqual(1, (Integer)outputs[0].totalEventos);
        Assert.isNotNull(outputs[0].eventosJson);
    }
    
    @isTest
    static void testPesquisarEventosVazio() {
        AgentPesquisarEventos.Input inp = new AgentPesquisarEventos.Input();
        inp.nomeEvento = 'NON_EXISTENT';
        
        Test.startTest();
        List<AgentPesquisarEventos.Output> outputs = AgentPesquisarEventos.pesquisarEventos(new List<AgentPesquisarEventos.Input>{inp});
        Test.stopTest();
        
        Assert.areEqual(0, (Integer)outputs[0].totalEventos);
        Assert.areEqual('[]', outputs[0].eventosJson);
    }

    @isTest
    static void testPesquisarEventosFiltros() {
        Evento__c ev = AgentTestDataFactory.createEvento();
        
        AgentPesquisarEventos.Input inp = new AgentPesquisarEventos.Input();
        inp.cidade = 'Lisboa';
        inp.categoria = 'Musica';
        inp.apenasDestaques = false;
        inp.precoMax = 100.00;
        
        Test.startTest();
        List<AgentPesquisarEventos.Output> outputs = AgentPesquisarEventos.pesquisarEventos(new List<AgentPesquisarEventos.Input>{inp});
        Test.stopTest();
        
        Assert.areEqual(1, (Integer)outputs[0].totalEventos);
    }
}
