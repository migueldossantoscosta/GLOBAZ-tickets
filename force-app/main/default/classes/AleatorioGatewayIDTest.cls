@isTest
public class AleatorioGatewayIDTest {

    @isTest
    static void testGerarID() {
        
        // =========================================================
        // EXECUTAR O TESTE (Chamar o teu método mágico)
        // =========================================================
        Test.startTest();
        
        // Chamamos a classe tal como o Flow faria
        List<String> resultado = AleatorioGatewayID.gerarID();
        
        Test.stopTest();

        // =========================================================
        // VERIFICAR OS RESULTADOS (Asserts do Arquiteto)
        // =========================================================
        
        // 1. Garantir que a classe devolveu alguma coisa e que é só 1 ID
        System.assertNotEquals(null, resultado, 'A classe não devolveu nada!');
        System.assertEquals(1, resultado.size(), 'A classe deveria ter devolvido exatamente 1 ID na lista.');

        // Extrair o ID gerado para analisá-lo
        String idGerado = resultado[0];
        
        // 2. Garantir que começa por "GW-"
        System.assert(idGerado.startsWith('GW-'), 'O ID gerado não tem o prefixo "GW-". ID gerado: ' + idGerado);
        
        // 3. Garantir que tem exatamente 13 caracteres (3 do "GW-" + 10 aleatórios)
        System.assertEquals(13, idGerado.length(), 'O tamanho do ID não está correto.');
    }
}