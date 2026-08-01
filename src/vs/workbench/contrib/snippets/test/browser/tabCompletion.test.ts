/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import assert from 'assert';
import { generateUuid } from '../../../../../base/common/uuid.js';
import { mock } from '../../../../../base/test/common/mock.js';
import { Handler } from '../../../../../editor/common/editorCommon.js';
import { SnippetController2 } from '../../../../../editor/contrib/snippet/browser/snippetController2.js';
import { withTestCodeEditor } from '../../../../../editor/test/browser/testCodeEditor.js';
import { ServiceCollection } from '../../../../../platform/instantiation/common/serviceCollection.js';
import { ensureNoDisposablesAreLeakedInTestSuite } from '../../../../../base/test/common/utils.js';
import { ISnippetsService } from '../../browser/snippets.js';
import { Snippet, SnippetSource } from '../../browser/snippetsFile.js';
import { TabCompletionController } from '../../browser/tabCompletion.js';

suite('TabCompletionController', () => {

	ensureNoDisposablesAreLeakedInTestSuite();

	function createSnippet(prefix: string, body: string, autoExpand: boolean): Snippet {
		return new Snippet(false, [], prefix, prefix, '', body, 'test', SnippetSource.User, generateUuid(), undefined, undefined, undefined, autoExpand);
	}

	function assertTypedValue(snippets: Snippet[], typedText: string, expected: string): void {
		const snippetService = new class extends mock<ISnippetsService>() {
			override getSnippetsSync(): Snippet[] {
				return snippets;
			}
		};
		const serviceCollection = new ServiceCollection([ISnippetsService, snippetService]);

		withTestCodeEditor('', { serviceCollection }, editor => {
			editor.registerAndInstantiateContribution(SnippetController2.ID, SnippetController2);
			editor.registerAndInstantiateContribution(TabCompletionController.ID, TabCompletionController);
			for (const character of typedText) {
				editor.trigger('keyboard', Handler.Type, { text: character });
			}
			assert.strictEqual(editor.getValue(), expected);
		});
	}

	test('expands an opted-in snippet when its exact prefix is typed', () => {
		assertTypedValue([createSnippet('log', 'console.log($1);', true)], 'log', 'console.log();');
	});

	test('does not expand a snippet that is not opted in', () => {
		assertTypedValue([createSnippet('log', 'console.log($1);', false)], 'log', 'log');
	});

	test('expands an opted-in snippet anywhere in a line', () => {
		assertTypedValue([createSnippet('ma', 'map(item => $1)', true)], 'array.ma', 'array.map(item => )');
	});

	test('does not expand an ambiguous prefix', () => {
		assertTypedValue([
			createSnippet('log', 'console.log($1);', true),
			createSnippet('log', 'logger.info($1);', true),
		], 'log', 'log');
	});
});