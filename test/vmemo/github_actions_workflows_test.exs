defmodule Vmemo.GitHubActionsWorkflowsTest do
  use ExUnit.Case, async: true

  @workflow_dir ".github/workflows"
  @pinned_action ~r/@[0-9a-f]{40}\s+#\s+v[0-9]/

  test "release workflows publish Vmemo images to GHCR through a reusable workflow" do
    assert workflow_exists?("release.yml")
    assert workflow_exists?("release-manual.yml")
    assert workflow_exists?("docker-publish.yml")
    refute workflow_exists?("update-dockerhub-description.yml")
    refute workflow_exists?("publish-docker-image.yml")

    docker_publish = read_workflow!("docker-publish.yml")
    release = read_workflow!("release.yml")
    release_manual = read_workflow!("release-manual.yml")

    assert docker_publish =~ "workflow_call:"
    assert docker_publish =~ "packages: write"
    assert docker_publish =~ "images: ghcr.io/thaddeusjiang/vmemo"
    assert docker_publish =~ "registry: ghcr.io"
    assert docker_publish =~ "password: ${{ secrets.GITHUB_TOKEN }}"
    assert docker_publish =~ "type=raw,value=latest,enable=${{ !inputs.is_prerelease }}"
    assert docker_publish =~ "type=raw,value=stag,enable=${{ inputs.is_prerelease }}"
    assert docker_publish =~ "type=raw,value=${{ inputs.version }}"
    assert docker_publish =~ "docker buildx imagetools inspect"

    assert release =~ "types:"
    assert release =~ "published"
    assert release =~ "uses: ./.github/workflows/docker-publish.yml"
    assert release =~ "is_prerelease: ${{ needs.prepare.outputs.is_prerelease == 'true' }}"

    assert release_manual =~ "workflow_dispatch:"
    assert release_manual =~ "Release tag to create"
    assert release_manual =~ "--prerelease"
    assert release_manual =~ "uses: ./.github/workflows/docker-publish.yml"
    assert release_manual =~ "is_prerelease: true"
  end

  test "workflows do not use Docker Hub, GitHub cache, or GitHub artifacts" do
    all_workflows = all_workflow_text()

    refute all_workflows =~ "Docker Hub"
    refute all_workflows =~ "DockerHub"
    refute all_workflows =~ "DOCKERHUB"
    refute all_workflows =~ "dockerhub"
    refute all_workflows =~ "actions/cache"
    refute all_workflows =~ "actions/upload-artifact"
    refute all_workflows =~ "actions/download-artifact"
  end

  test "external workflow actions are pinned to commit SHAs with version comments" do
    unpinned_actions =
      workflow_paths()
      |> Enum.flat_map(fn path ->
        path
        |> File.read!()
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _line_number} ->
          String.contains?(line, "uses:") and
            String.contains?(line, "@") and
            not String.contains?(line, "uses: ./")
        end)
        |> Enum.reject(fn {line, _line_number} -> Regex.match?(@pinned_action, line) end)
        |> Enum.map(fn {line, line_number} -> "#{path}:#{line_number}:#{String.trim(line)}" end)
      end)

    assert unpinned_actions == []
  end

  defp workflow_exists?(filename), do: File.exists?(Path.join(@workflow_dir, filename))

  defp read_workflow!(filename), do: File.read!(Path.join(@workflow_dir, filename))

  defp all_workflow_text do
    workflow_paths()
    |> Enum.map(&File.read!/1)
    |> Enum.join("\n")
  end

  defp workflow_paths do
    @workflow_dir
    |> Path.join("*.yml")
    |> Path.wildcard()
    |> Enum.sort()
  end
end
