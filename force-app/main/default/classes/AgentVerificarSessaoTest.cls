@isTest
private class AgentVerificarSessaoTest {
    @isTest
    static void testVerificarSessaoSuccess() {
        Account acc = AgentTestDataFactory.createPersonAccount();

        AgentVerificarSessao.Input inp = new AgentVerificarSessao.Input();
        inp.accountId = acc.Id;

        Test.startTest();
        List<AgentVerificarSessao.Output> results = AgentVerificarSessao.verificarSessao(new List<AgentVerificarSessao.Input>{inp});
        Test.stopTest();

        Assert.isTrue(results[0].isLoggedIn, 'Utilizador deveria estar autenticado');
        Assert.areEqual(acc.FirstName, results[0].firstName);
        Assert.areEqual(acc.PersonEmail, results[0].email);
    }

    @isTest
    static void testVerificarSessaoNoAccount() {
        AgentVerificarSessao.Input inp = new AgentVerificarSessao.Input();
        inp.accountId = null;

        Test.startTest();
        List<AgentVerificarSessao.Output> results = AgentVerificarSessao.verificarSessao(new List<AgentVerificarSessao.Input>{inp});
        Test.stopTest();

        Assert.isFalse(results[0].isLoggedIn);
        Assert.isNotNull(results[0].erroMsg);
    }

    @isTest
    static void testVerificarSessaoInvalidId() {
        AgentVerificarSessao.Input inp = new AgentVerificarSessao.Input();
        inp.accountId = 'invalid_id';

        Test.startTest();
        List<AgentVerificarSessao.Output> results = AgentVerificarSessao.verificarSessao(new List<AgentVerificarSessao.Input>{inp});
        Test.stopTest();

        Assert.isFalse(results[0].isLoggedIn);
        Assert.areEqual('ID de sessao invalido.', results[0].erroMsg);
    }
}