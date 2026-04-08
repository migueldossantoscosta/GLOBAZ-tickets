@isTest
public class AgentCriarCaseSuporteTest {
    @isTest
    static void testCriarCaseSucesso() {
        Account acc = AgentTestDataFactory.createPersonAccount();
        
        AgentCriarCaseSuporte.Input inp = new AgentCriarCaseSuporte.Input();
        inp.accountId = acc.Id;
        inp.email = acc.PersonEmail;
        inp.assunto = 'Test Subject';
        inp.descricao = 'Test Description';
        inp.tipo = 'Dúvida';
        
        Test.startTest();
        List<AgentCriarCaseSuporte.Output> outputs = AgentCriarCaseSuporte.criarCase(new List<AgentCriarCaseSuporte.Input>{inp});
        Test.stopTest();
        
        Assert.isTrue(outputs[0].sucesso);
        Assert.isNotNull(outputs[0].caseId);
        Assert.isNotNull(outputs[0].caseNumber);
    }
}
