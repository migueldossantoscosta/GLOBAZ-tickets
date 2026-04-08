@isTest
public class AgentVerificarSessaoTest {
    @isTest
    static void testVerificarSessaoSucesso() {
        Account acc = AgentTestDataFactory.createPersonAccount();
        
        AgentVerificarSessao.Input inp = new AgentVerificarSessao.Input();
        inp.accountId = acc.Id;
        
        Test.startTest();
        List<AgentVerificarSessao.Output> outputs = AgentVerificarSessao.verificarSessao(new List<AgentVerificarSessao.Input>{inp});
        Test.stopTest();
        
        Assert.isTrue(outputs[0].isLoggedIn, 'User should be logged in');
        Assert.areEqual(acc.PersonEmail, outputs[0].email);
    }
    
    @isTest
    static void testVerificarSessaoErro() {
        AgentVerificarSessao.Input inp = new AgentVerificarSessao.Input();
        inp.accountId = null;
        
        Test.startTest();
        List<AgentVerificarSessao.Output> outputs = AgentVerificarSessao.verificarSessao(new List<AgentVerificarSessao.Input>{inp});
        Test.stopTest();
        
        Assert.isFalse(outputs[0].isLoggedIn);
        Assert.isNotNull(outputs[0].erroMsg);
    }
}
